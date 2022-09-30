import HealthKit
import Combine
import os.log
import VitalCore

public enum PermissionOutcome {
  case success
  case failure(String)
  case healthKitNotAvailable
}

public class VitalHealthKitClient {
  public enum Status {
    case failedSyncing(VitalResource, Error?)
    case successSyncing(VitalResource, PostResourceData)
    case nothingToSync(VitalResource)
    case syncing(VitalResource)
    case syncingCompleted
  }
  
  public static var shared: VitalHealthKitClient {
    guard let value = client else {
      let newClient = VitalHealthKitClient()
      return newClient
    }
    
    return value
  }
  
  private static var client: VitalHealthKitClient?
  
  private let store: VitalHealthKitStore
  private let storage: VitalHealthKitStorage
  private let secureStorage: VitalSecureStorage
  private let vitalClient: VitalClientProtocol
  
  private let _status: PassthroughSubject<Status, Never>
  private var backgroundDeliveryTask: Task<Void, Error>? = nil
  
  private let backgroundDeliveryEnabled: ProtectedBox<Bool> = .init(value: false)
  let configuration: ProtectedBox<Configuration>

  public var status: AnyPublisher<Status, Never> {
    return _status.eraseToAnyPublisher()
  }
  
  private var logger: Logger? = nil
  
  init(
    configuration: ProtectedBox<Configuration> = .init(),
    store: VitalHealthKitStore = .live,
    storage: VitalHealthKitStorage = .init(storage: .live),
    secureStorage: VitalSecureStorage = .init(keychain: .live),
    vitalClient: VitalClientProtocol = .live
  ) {
    self.store = store
    self.storage = storage
    self.secureStorage = secureStorage
    self.vitalClient = vitalClient
    self.configuration = configuration
    
    self._status = PassthroughSubject<Status, Never>()
    
    VitalHealthKitClient.client = self
  }
  
  public static func configure(
    _ configuration: Configuration = .init()
  ) async {
      await self.shared.setConfiguration(configuration: configuration)
  }
  
  public static func automaticConfiguration() async {
    do {
      let secureStorage = self.shared.secureStorage
      guard let payload: Configuration = try secureStorage.get(key: health_secureStorageKey) else {
        return
      }
      
      await configure(payload)
      await VitalClient.automaticConfiguration()
    }
    catch {
      /// Bailout, there's nothing else to do here.
    }
  }
  
  func setConfiguration(
    configuration: Configuration
  ) async {
    if configuration.logsEnabled {
      self.logger = Logger(subsystem: "vital", category: "vital-healthkit-client")
    }
    
    do {
      try secureStorage.set(value: configuration, key: health_secureStorageKey)
    }
    catch {
      logger?.info("We weren't able to securely store Configuration: \(error.localizedDescription)")
    }
    
    await self.configuration.set(value: configuration)
    
    if await backgroundDeliveryEnabled.get() == false {
      await backgroundDeliveryEnabled.set(value: true)
      
      let resources = resourcesAskedForPermission(store: self.store)
      checkBackgroundUpdates(isBackgroundEnabled: configuration.backgroundDeliveryEnabled, resources: resources)
    }
  }
}

public extension VitalHealthKitClient {
  struct Configuration: Codable {
    public enum DataPushMode: String, Codable {
      case manual
      case automatic
      
      var isManual: Bool {
        switch self {
          case .manual:
            return true
          case .automatic:
            return false
        }
      }
      
      var isAutomatic: Bool {
        return isManual == false
      }
    }
    
    public let backgroundDeliveryEnabled: Bool
    public let logsEnabled: Bool
    public let numberOfDaysToBackFill: Int
    public let mode: DataPushMode
    
    public init(
      backgroundDeliveryEnabled: Bool = false,
      logsEnabled: Bool = true,
      numberOfDaysToBackFill: Int = 90,
      mode: DataPushMode = .automatic
    ) {
      self.backgroundDeliveryEnabled = backgroundDeliveryEnabled
      self.logsEnabled = logsEnabled
      self.numberOfDaysToBackFill = numberOfDaysToBackFill
      self.mode = mode
    }
  }
}

extension VitalHealthKitClient {
  
  private func checkBackgroundUpdates(isBackgroundEnabled: Bool, resources: [VitalResource]) {
    guard isBackgroundEnabled else { return }
    guard resources.isEmpty == false else { return }
    
    /// If it's already running, cancel it
    self.backgroundDeliveryTask?.cancel()
    
    let allowedSampleTypes = Set(resources.flatMap(toHealthKitTypes(resource:)))
    let common = Set(observedSampleTypes()).intersection(allowedSampleTypes)
    let sampleTypes = common.compactMap { $0 as? HKSampleType }
    
    /// Enable background deliveries
    enableBackgroundDelivery(for: sampleTypes)
    
    let stream = backgroundObservers(for: sampleTypes)
    self.backgroundDeliveryTask = Task(priority: .high) {
      for await payload in stream {
        /// Sync a sample one-by-one
        await sync(payload: .type(payload.sampleType), completion: payload.completion)
      }
    }
  }
  
  private func enableBackgroundDelivery(for sampleTypes: [HKSampleType]) {
    for sampleType in sampleTypes {
      store.enableBackgroundDelivery(sampleType, .hourly) { [weak self] success, failure in
        
        guard failure == nil && success else {
          self?.logger?.error("Failed to enable background delivery for type: \(String(describing: sampleType)). Did you enable \"Background Delivery\" in Capabilities?")
          return
        }
        
        self?.logger?.info("Successfully enabled background delivery for type: \(String(describing: sampleType))")
      }
    }
  }
  
  private func backgroundObservers(
    for sampleTypes: [HKSampleType]
  ) -> AsyncStream<BackgroundDeliveryPayload> {
    
    return AsyncStream<BackgroundDeliveryPayload> { continuation in
      
      var queries: [HKObserverQuery] = []
      
      for sampleType in sampleTypes {
        let query = HKObserverQuery(sampleType: sampleType, predicate: nil) {[weak self] query, handler, error in
                    
          guard error == nil else {
            self?.logger?.error("Failed to background deliver for \(String(describing: sampleType)).")
            
            ///  We need a better way to handle if a failure happens here.
            return
          }
          
          let payload = BackgroundDeliveryPayload(sampleType: sampleType, completion: handler)
          continuation.yield(payload)
        }
        
        queries.append(query)
        store.execute(query)
      }
      
      /// If the task is cancelled, make sure we clean up the existing queries
      continuation.onTermination = { @Sendable [queries] _ in
        queries.forEach { query in
          self.store.stop(query)
        }
      }
    }
  }
  
  private func calculateStage(
    resource: VitalResource,
    startDate: Date,
    endDate: Date
  ) -> TaggedPayload.Stage  {
    
    /// We don't keep a historical record for profile data
    if resource == .profile {
      return .daily
    }
    
    return storage.readFlag(for: resource) ? .daily : .historical(start: startDate, end: endDate)
  }
  
  public func syncData() {
    let resources = resourcesAskedForPermission(store: store)
    syncData(for: resources)
  }
  
  public func syncData(for resources: [VitalResource]) {
    Task(priority: .high) {
      for resource in resources {
        await sync(payload: .resource(resource), completion: {})
      }
      
      _status.send(.syncingCompleted)
    }
  }
    
  public enum SyncPayload {
    case type(HKSampleType)
    case resource(VitalResource)
    
    var isResource: Bool {
      switch self {
        case .resource:
          return true
        case .type:
          return false
      }
    }
    
    var infix: String {
      if isResource {
        return ""
      } else {
        return "(via background delivery mechanism)"
      }
    }
    
    func description(store: VitalHealthKitStore) -> String {
      switch self {
        case let .resource(resource):
          return resource.logDescription
          
        case let .type(type):
          /// We know that if we are dealing with
          return store.toVitalResource(type).logDescription
      }
    }
    
    func resource(store: VitalHealthKitStore) -> VitalResource {
      switch self {
        case let .resource(resource):
          return resource
          
        case let .type(type):
          return store.toVitalResource(type)
      }
    }
  }
  
  private func sync(
    payload: SyncPayload,
    completion: () -> Void
  ) async {
    
    let configuration = await configuration.get()
    let startDate: Date = .dateAgo(days: configuration.numberOfDaysToBackFill)
    let endDate: Date = Date()
    
    let infix = payload.infix
    let description = payload.description(store: store)
    let resource = payload.resource(store: store)
    
    logger?.info("Syncing HealthKit \(infix): \(description)")
    
    do {
      // Signal syncing (so the consumer can convey it to the user)
      _status.send(.syncing(resource))
      
      // Fetch from HealthKit
      let (data, entitiesToStore): (PostResourceData, [StoredAnchor])
      
      (data, entitiesToStore) = try await store.readResource(
        resource,
        startDate,
        endDate,
        storage
      )
      
      let stage = calculateStage(
        resource: payload.resource(store: store),
        startDate: startDate,
        endDate: endDate
      )
      
      /// If it's historical, even if there's no data, we still push
      /// If there's no data and it's daily, then we bailout.
      guard data.shouldSkipPost == false || stage.isDaily == false else {
        logger?.info("Skipping. No new data available \(infix): \(description)")
        _status.send(.nothingToSync(resource))
        return
      }
      
      if configuration.mode.isAutomatic {
        self.logger?.info(
          "Automatic Mode. Posting data for stage \(stage) \(infix): \(description)"
        )
        
        /// Make sure the user has a connected source set up
        try await vitalClient.checkConnectedSource(.appleHealthKit)
        
        // Post data
        try await vitalClient.post(
          data,
          stage,
          .appleHealthKit,
          TimeZone.autoupdatingCurrent
        )
      } else {
        self.logger?.info(
          "Manual Mode. Skipping posting data for stage \(stage) \(infix): \(description)"
        )
      }
      
      // This is used for calculating the stage (daily vs historic)
      storage.storeFlag(for: resource)
      
      // Save the anchor/date on a succesfull network call
      entitiesToStore.forEach(storage.store(entity:))
      
      logger?.info("Completed syncing \(infix): \(description)")
      
      // Signal success
      _status.send(.successSyncing(resource, data))
      
      /// Call completion
      completion()
      
    }
    catch let error {
      // Signal failure
      logger?.error(
        "Failed syncing data \(infix): \(description). Error: \(error.localizedDescription)"
      )
      _status.send(.failedSyncing(resource, error))
    }
  }
  
  public func ask(
    for resources: [VitalResource]
  ) async -> PermissionOutcome {
    
    guard store.isHealthDataAvailable() else {
      return .healthKitNotAvailable
    }
    
    do {
      let configuration = await configuration.get()
      try await store.requestReadAuthorization(resources)
      checkBackgroundUpdates(
        isBackgroundEnabled: configuration.backgroundDeliveryEnabled,
        resources: resources
      )
      
      return .success
    }
    catch let error {
      return .failure(error.localizedDescription)
    }
  }
  
  public func hasAskedForPermission(resource: VitalResource) -> Bool {
    store.hasAskedForPermission(resource)
  }
}
