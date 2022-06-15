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
    
    if configuration.logsEnable {
      self.logger = Logger(subsystem: "vital", category: "vital-healthkit-client")
    }
    
    let resources = resourcesAskedForPermission(store: self.store)
    setupBackgroundUpdates(resources: resources)
  }
}

public extension VitalHealthKitClient {
  struct Configuration {
    public let autoSync: Bool
    public let backgroundUpdates: Bool
    public let logsEnable: Bool
    
    public init(
      autoSync: Bool = false,
      backgroundUpdates: Bool = false,
      logsEnable: Bool = true
    ) {
      self.autoSync = autoSync
      // More testing is required before exposing this feature
      self.backgroundUpdates = backgroundUpdates
      self.logsEnable = logsEnable
    }
  }
}

extension VitalHealthKitClient {
  private func setupBackgroundUpdates(resources: [VitalResource]) {
      guard self.configuration.backgroundUpdates else { return }
      guard resources.isEmpty == false else { return }
      
      
      let allowedSampleTypes = Set(resources.flatMap(toHealthKitTypes(resource:)))
      let common = Set(observedSampleTypes()).intersection(allowedSampleTypes)
      let toSampleTypes = common.compactMap { $0 as? HKSampleType }
      
      self.logger?.info("Syncing data for \n\(toSampleTypes)\n")
    
      for sampleType in toSampleTypes {
        
        self.store.enableBackgroundDelivery(sampleType, .immediate) { [weak self] success, failure in
          
          guard failure == nil && success else {
            self?.logger?.error("Failed to enable background delivery for type: \(String(describing: sampleType)). Did you enable \"Background Delivery\" in Capabilities?")
            return
          }
          
          self?.logger?.info("Successfully enabled background delivery for type: \(String(describing: sampleType))")
        }
        
        let query = HKObserverQuery(sampleType: sampleType, predicate: nil) {[weak self] query, handler, error in
          
          guard let strongSelf = self else { return }
          
          guard error == nil else {
            self?.logger?.error("Failed to background deliver for \(String(describing: sampleType)).")
            return
          }
          
          Task(priority: .high) {
            print("->>>>>>>\(String(describing: sampleType))")
            try await strongSelf.vitaClient.checkConnectedSource(.appleHealthKit)
            await strongSelf.sync(type: sampleType, completion: handler)
          }
        }
        
        self.store.execute(query)
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
      try await vitaClient.checkConnectedSource(.appleHealthKit)

      for resource in resources {
        await sync(resource: resource)
      }
      
      _status.send(.syncingCompleted)
    }
  }
  
  private func sync(
    type: HKSampleType,
    completion: () -> Void
  ) async {
    let startDate: Date = .dateAgo(days: 30)
    let endDate: Date = Date()
    
    self.logger?.info("Syncing HealthKit in background for type: \(String(describing: type))")
    
    do {
      
      let stage = calculateStage(resource: type.toVitalResource, startDate: startDate, endDate: endDate)
      
      self.logger?.info("Reading data in background for: \(String(describing: type))")
      
      let (data, entitiesToStore) = try await store.readSample(
        type,
        stage,
        startDate,
        endDate,
        storage
      )
      
      guard data.shouldSkipPost == false else {
        self.logger?.info("Skipping background delivery. No new data available for type: \(String(describing: type))")
        return
      }
      
      // Post to the network
      self.logger?.info("Posting data in background for: \(String(describing: type))")

      try await vitaClient.post(
        data,
        stage,
        .appleHealthKit
      )
      
      storage.storeFlag(for: type.toVitalResource)
      
      // Save the anchor/date on succesfull network call
      entitiesToStore.forEach(storage.store(entity:))
      
      self.logger?.info("Completed background syncing for type: \(String(describing: type))")
      
      /// Call completion
      completion()
    }
    catch let error {
      // Signal failure
      self.logger?.error(
        "Failed background syncing for type: \(String(describing: type)). Error: \(error.localizedDescription)"
      )
    }
  }
  
  private func sync(
    resource: VitalResource
  ) async {
    
    let startDate: Date = .dateAgo(days: 30)
    let endDate: Date = Date()
    
    self.logger?.info("Syncing HealthKit data for: \(resource.logDescription)")
    
    do {
      // Signal syncing (so the consumer can convey it to the user)
      _status.send(.syncing(resource))
      
      // Fetch from HealthKit
      let (data, entitiesToStore) = try await store.readResource(
        resource,
        startDate,
        endDate,
        storage
      )
      
      guard data.shouldSkipPost == false else {
        self.logger?.info("Skipping. No new data available for: \(resource.logDescription)")
        _status.send(.nothingToSync(resource))
        return
      }
      
      // Calculate if this daily data or historical
      let stage = calculateStage(
        resource: resource,
        startDate: startDate,
        endDate: endDate
      )
      
      // Post to the network
      self.logger?.info("Posting data for: \(resource.logDescription)")
      
      try await vitaClient.post(
        data,
        stage,
        .appleHealthKit
      )
      
      storage.storeFlag(for: resource)
      
      // Save the anchor/date on succesfull network call
      entitiesToStore.forEach(storage.store(entity:))
      
      self.logger?.info("Completed syncing for: \(resource.logDescription)")
      
      // Signal success
      _status.send(.successSyncing(resource, data))
    }
    catch let error {
      // Signal failure
      self.logger?.error(
        "Failed syncing data for: \(resource.logDescription). Error: \(error.localizedDescription)"
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
      try await store.requestReadAuthorization(resources)
      setupBackgroundUpdates(resources: resources)
      
      return .success
    }
    catch let error {
      return .failure(error.localizedDescription)
    }
  }
}

