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
    guard let client = Self.client else {
      fatalError("`VitalHealthKitClient` hasn't been configured. Please call `VitalHealthKitClient.configure()`")
    }
    
    return client
  }
  
  private static var client: VitalHealthKitClient?
  
  public static func configure(
    _ configuration: Configuration = .init()
  ) {
    let client = VitalHealthKitClient(configuration: configuration)
    Self.client = client
  }
  
  private let store: VitalHealthKitStore
  private let configuration: Configuration
  private let storage: VitalHealthKitStorage
  private let vitaClient: VitalClientProtocol
  
  private let _status: PassthroughSubject<Status, Never>
  private var backgroundDeliveryTask: Task<Void, Error>? = nil
  
  public var status: AnyPublisher<Status, Never> {
    return _status.eraseToAnyPublisher()
  }
  
  private var logger: Logger? = nil
  
  init(
    configuration: Configuration,
    store: VitalHealthKitStore = .live,
    storage: VitalHealthKitStorage = .init(),
    vitaClient: VitalClientProtocol = .live
  ) {
    self.store = store
    self.configuration = configuration
    self.storage = storage
    self.vitaClient = vitaClient
    
    self._status = PassthroughSubject<Status, Never>()
    
    if configuration.logsEnabled {
      self.logger = Logger(subsystem: "vital", category: "vital-healthkit-client")
    }
    
    let resources = resourcesAskedForPermission(store: self.store)
    checkBackgroundUpdates(isBackgroundEnabled: configuration.backgroundDeliveryEnabled, resources: resources)
  }
}

public extension VitalHealthKitClient {
  struct Configuration {
    public enum DataPushMode {
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
      self.store.enableBackgroundDelivery(sampleType, .immediate) { [weak self] success, failure in
        
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
        self.store.execute(query)
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
    
  public enum SyncPayloadd {
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
    
    var resource: VitalResource {
      switch self {
        case let .resource(resource):
          return resource
          
        case let .type(type):
          return type.toVitalResource
      }
    }
  }
  
  private func sync(
    payload: SyncPayloadd,
    completion: () -> Void
  ) async {
    
    let startDate: Date = .dateAgo(days: configuration.numberOfDaysToBackFill)
    let endDate: Date = Date()
    
    self.logger?.info("Syncing HealthKit \(payload.infix): \(payload.description)")
    
    do {
      // Signal syncing (so the consumer can convey it to the user)
      _status.send(.syncing(payload.resource))
      
      // Fetch from HealthKit
      let (data, entitiesToStore): (PostResourceData, [StoredAnchor])
      
      (data, entitiesToStore) = try await store.readResource(
        payload.resource,
        startDate,
        endDate,
        storage
      )
      
      guard data.shouldSkipPost == false else {
        self.logger?.info("Skipping. No new data available \(payload.infix): \(payload.description)")
        _status.send(.nothingToSync(payload.resource))
        return
      }
      
      let stage = calculateStage(
        resource: payload.resource,
        startDate: startDate,
        endDate: endDate
      )
      
      
      if configuration.mode.isAutomatic {
        self.logger?.info(
          "Automatic Mode. Posting data for stage \(String(describing: stage)) \(payload.infix): \(payload.description)"
        )
        
        /// Make sure the user has a connected source set up
        try await vitaClient.checkConnectedSource(.appleHealthKit)
        
        // Post data
        try await vitaClient.post(
          data,
          stage,
          .appleHealthKit
        )
      } else {
        self.logger?.info(
          "Manual Mode. Skipping posting data for stage \(String(describing: stage)) \(payload.infix): \(payload.description)"
        )
      }
      
      // This is used for calculating the stage (daily vs historic)
      storage.storeFlag(for: payload.resource)
      
      // Save the anchor/date on a succesfull network call
      entitiesToStore.forEach(storage.store(entity:))
      
      self.logger?.info("Completed syncing \(payload.infix): \(payload.description)")
      
      // Signal success
      _status.send(.successSyncing(payload.resource, data))
      
      /// Call completion
      completion()
      
    }
    catch let error {
      // Signal failure
      self.logger?.error(
        "Failed syncing data \(payload.infix): \(payload.description). Error: \(error.localizedDescription)"
      )
      _status.send(.failedSyncing(payload.resource, error))
    }
  }
  
  public func ask(
    for resources: [VitalResource]
  ) async -> PermissionOutcome {
    
    guard store.isHealthDataAvailable() else {
      return .healthKitNotAvailable
    }
    
    do {
      try await store.requestReadAuthorization(resources)
      checkBackgroundUpdates(
        isBackgroundEnabled: self.configuration.backgroundDeliveryEnabled,
        resources: resources
      )
      
      return .success
    }
    catch let error {
      return .failure(error.localizedDescription)
    }
  }
}
