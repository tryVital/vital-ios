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
    case syncing(VitalResource)
    case failedSyncing(VitalResource, Error?)
    case successSyncing(VitalResource)
  }
  
  public static var shared: VitalHealthKitClient {
    guard let client = Self.client else {
      fatalError("`VitalHealthKitClient` hasn't been configured.")
    }
    
    return client
  }
  
  private static var client: VitalHealthKitClient?
  
  public static func configure(
    _ configuration: Configuration = .init()
  ) {
    let client = VitalHealthKitClient(configuration: configuration)
    Self.client = client
    
    if configuration.autoSync {
      client.syncData()
    }
  }
  
  private let store: HKHealthStore
  private let configuration: Configuration
  private let vitalStorage: VitalStorage
  
  private let _status: PassthroughSubject<Status, Never>
  
  public var status: AnyPublisher<Status, Never> {
    return _status.eraseToAnyPublisher()
  }
  
  private var logger: Logger? = nil

  
  init(configuration: Configuration) {
    self.store = HKHealthStore()
    self.vitalStorage = VitalStorage()
    self.configuration = configuration
    self._status = PassthroughSubject<Status, Never>()
    
    if configuration.logsEnable {
      self.logger = Logger(subsystem: "vital", category: "vital-healthkit-client")
    }
    
    if configuration.backgroundUpdates {
      for type in allTypesForBackgroundDelivery() {
        self.store.enableBackgroundDelivery(for: type, frequency: .immediate) {[weak self] success, failure in
          
          guard failure == nil && success else {
            self?.logger?.log(level: .error, "Failed to enable background delivery for \(String(describing: type)). This is a developer mistake")
            return
          }
          
          self?.logger?.log(level: .info, "Succesfully enabled background delivery for \(String(describing: type))")
        }
      }
    }
  }
}

public extension VitalHealthKitClient {
  struct Configuration {
    public let autoSync: Bool
    public let backgroundUpdates: Bool
    public let logsEnable: Bool
    
    public init(
      autoSync: Bool = false,
      logsEnable: Bool = true
    ) {
      self.autoSync = autoSync
      self.backgroundUpdates = false
      self.logsEnable = logsEnable
    }
  }
}

extension VitalHealthKitClient {
  
  private func calculateStage(
    resource: VitalResource,
    startDate: Date,
    endDate: Date
  ) -> TaggedPayload.Stage  {
    
    /// We don't keep a historical record for profile data
    if resource == .profile {
      return .daily
    }
    
    return vitalStorage.readFlag(for: resource) ? .daily : .historical(start: startDate, end: endDate)
  }
  
  public func syncData() {
    let resources = resourcesAskedForPermission(store: store)
    syncData(for: resources)
  }
  
  public func syncData(for resources: [VitalResource]){
    Task(priority: .high) {
      
      let startDate: Date = .dateAgo(days: 30)
      let endDate: Date = Date()
      
      for resource in resources {
        do {
          
          // Signal syncing (so the consumer can convey it to the user)
          _status.send(.syncing(resource))
          
          // Fetch from HealthKit
          let (summaryToPost, entitiesToStore) = try await handle(
            resource: resource,
            store: store,
            vitalStorage: vitalStorage,
            startDate: startDate,
            endDate: endDate
          )
          
          // If there's no data, don't post it
          
          let stage = calculateStage(
            resource: resource,
            startDate: startDate,
            endDate: endDate
          )
          
          // Post to the network
          try await VitalNetworkClient.shared.summary.post(
            resource: summaryToPost,
            stage: stage,
            provider: .appleHealthKit
          )
          
          vitalStorage.storeFlag(for: resource)
          
          // Save the anchor/date on succesfull network call
          entitiesToStore.forEach(vitalStorage.store(entity:))
          
          // Signal success
          _status.send(.successSyncing(resource))
          
        }
        catch let error {
          // Signal failure
          _status.send(.failedSyncing(resource, error))
          return
        }
      }
    }
  }
  
  public func ask(
    for resources: [VitalResource],
    completion: @escaping (PermissionOutcome) -> Void = { _ in }
  ) {
    guard HKHealthStore.isHealthDataAvailable() else {
      completion(.healthKitNotAvailable)
      return
    }
    
    let types = resources.flatMap(toHealthKitTypes)
    store.requestAuthorization(toShare: [], read: Set(types)) {[weak self] success, error in
      guard let self = self else {
        return
      }
      
      guard error == nil else {
        completion(.failure(error!.localizedDescription))
        return
      }
      
      guard success else {
        completion(.failure("Couldn't grant permissions"))
        return
      }
      
      self.syncData(for: resources)
    }
  }
}

