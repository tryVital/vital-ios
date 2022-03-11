import HealthKit
import os.log

public enum PermissionOutcome {
  case success
  case failure(String)
  case healthKitNotAvailable
}

public enum Permission {
  public enum Vitals {
    case glucose
  }
  
  case body
  case workouts
  case activity
  case sleep
  case vitals(Vitals)
  
  static var all: [Permission] = [.body, .workouts, .activity, .sleep, .vitals(.glucose)]
}

public class VitalHealthKitClient {
  public static var shared: VitalHealthKitClient {
    guard let client = Self.client else {
      fatalError("`VitalHealthKitClient` hasn't been configured.")
    }
    
    return client
  }
  
  private static var client: VitalHealthKitClient?
  
  private let store: HKHealthStore
  private let configuration: Configuration
  private let storage: AnchorStorage
  
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
    self.storage = AnchorStorage()
    self.configuration = configuration
    
    if configuration.logsEnable {
      self.logger = Logger(subsystem: "vital", category: "vital-healthkit-client")
    }
    
    if configuration.backgroundUpdates {
      for type in allTypesForBackgroundDelivery() {
        self.store.enableBackgroundDelivery(for: type, frequency: .immediate) {[weak self] success, failure in
          
          guard failure == nil && success else {
            self?.logger?.log(level: .error, "Failed to enable background delivery for \(String(describing: type))")
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
    let client = VitalHealthKitClient(configuration: configuration)
    Self.setInstance(client: client)
  }
  
  public static func set(userId: String) {
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
  
  private func _syncData(for types: [HKObjectType]){
    Task(priority: .high) {
      guard userId != nil else {
        self.logger?.log(
          level: .error,
          "Can't sync data: `userId` hasn't been set. Please use VitalHealthKitClient.set(userId: \"xyz\")"
        )
        
        return
      }
      
      for type in types {
        self.logger?.log(level: .info, "Syncing data for \(type)")
      }
      
      for type in types {
        do {
          let results = try await query(
            healthKitStore: store,
            anchtorStorage: storage,
            isBackgroundUpdating: configuration.backgroundUpdates,
            type: type
          )
        }
        catch {
          
        }
      }
    }
  }
  
  public func syncData() {
    let types = allTypesAskedForPermission(store: store)
    self._syncData(for: types)
  }
  
  public func ask(
    for permissions: [Permission],
    completion: @escaping (PermissionOutcome) -> Void = { _ in }
  ) {
    guard HKHealthStore.isHealthDataAvailable() else {
      completion(.healthKitNotAvailable)
      return
    }
    
    let types = permissions.flatMap(toHealthKitTypes)
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
      
      self._syncData(for: types)
    }
  }
}

