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
  
  private let store: HKHealthStore
  private let configuration: Configuration
  private let vitalStorage: VitalStorage
  
  private let _status: PassthroughSubject<Status, Never>
  
  public var status: AnyPublisher<Status, Never> {
    return _status.eraseToAnyPublisher()
  }
  
  private var logger: Logger? = nil
  private var userId: String? = nil {
    didSet {
      if configuration.autoSync {
        syncData()
      }
    }
  }
  
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
  
  private static func setInstance(client: VitalHealthKitClient) {
    guard Self.client == nil else {
      fatalError("`VitalHealthKitClient` is already configured.")
    }
    
    Self.client = client
  }
  
  public static func configure(
    clientId: String,
    clientSecret: String,
    environment: Environment,
    configuration: Configuration = .init()
  ) {
    VitalNetworkClient.configure(clientId: clientId, clientSecret: clientSecret, environment: environment)
    Self.setInstance(client: .init(configuration: configuration))
  }
  
  public static func set(userId: String) {
    VitalNetworkClient.setUserId(userId)
    self.shared.userId = userId
  }
}

public extension VitalHealthKitClient {
  struct Configuration {
    public let autoSync: Bool
    public let backgroundUpdates: Bool
    public let logsEnable: Bool
    
    public init(
      autoSync: Bool = true,
      backgroundUpdates: Bool = true,
      logsEnable: Bool = true
    ) {
      self.autoSync = autoSync
      self.backgroundUpdates = backgroundUpdates
      self.logsEnable = logsEnable
    }
  }
}

extension VitalHealthKitClient {
  
  private func _syncData(for resources: [VitalResource]){
    Task(priority: .high) {
      guard userId != nil else {
        self.logger?.log(
          level: .error,
          "Can't sync data: `userId` hasn't been set. Please use VitalHealthKitClient.set(userId: \"xyz\")"
        )
        
        return
      }
      
      for resource in resources {
        do {
          
          // Signal syncing (so the consumer can convey it to the user)
          _status.send(.syncing(resource))
          
          // Fetch from HealthKit
          let (encodable, entitiesToStore) = try await handle(
            resource: resource,
            store: store,
            vitalStorage: vitalStorage,
            isBackgroundUpdating: configuration.backgroundUpdates
          )
          
          // Post to the network
          // TODO
          
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
  
  public func syncData() {
    let resources = resourcesAskedForPermission(store: store)
    _syncData(for: resources)
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
      
      self._syncData(for: resources)
    }
  }
}

