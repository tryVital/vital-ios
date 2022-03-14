import HealthKit
import os.log

public enum PermissionOutcome {
  case success
  case failure(String)
  case healthKitNotAvailable
}

public enum Domain {
  public enum Vitals {
    case glucose
  }
  
  case profile
  case body
  case workouts
  case activity
  case sleep
  case vitals(Vitals)
  
  static var all: [Domain] = [
    .profile,
    .body,
    .workouts,
    .activity,
    .sleep,
    .vitals(.glucose),
    ]
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
  private let anchorStorage: AnchorStorage
  private let dateStorage: DateStorage

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
    self.anchorStorage = AnchorStorage()
    self.dateStorage = DateStorage()
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
  
  private func _syncData(for domains: [Domain]){
    Task(priority: .high) {
      guard userId != nil else {
        self.logger?.log(
          level: .error,
          "Can't sync data: `userId` hasn't been set. Please use VitalHealthKitClient.set(userId: \"xyz\")"
        )
        
        return
      }
      do {
        for domain in domains {
          switch domain {
            case .profile:
             let profilePayload = try await handleProfile(
                healthKitStore: store,
                anchtorStorage: anchorStorage
              )
            case .body:
             let bodyPayload = try await handleBody(
                healthKitStore: store,
                anchtorStorage: anchorStorage,
                isBackgroundUpdating: configuration.backgroundUpdates
              )
              
            case .sleep:
              let sleepPayload = try await handleSleep(
                healthKitStore: store,
                anchtorStorage: anchorStorage,
                isBackgroundUpdating: configuration.backgroundUpdates
              )
              
            case .activity:
              let activitiesPayload = try await handleActivity(
                healthKitStore: store,
                dateStorage: dateStorage
              )
              
            case .workouts:
              fatalError("Workouts not set")
              


            case .vitals(let vitals):
              fatalError()
          }
        }
      }
      catch let error {
        print(error)
      }
    }
  }
  
  public func syncData() {
    let domains = domainsAskedForPermission(store: store)
    self._syncData(for: domains)
  }
  
  public func ask(
    for domains: [Domain],
    completion: @escaping (PermissionOutcome) -> Void = { _ in }
  ) {
    guard HKHealthStore.isHealthDataAvailable() else {
      completion(.healthKitNotAvailable)
      return
    }
    
    let types = domains.flatMap(toHealthKitTypes)
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
      
      self._syncData(for: domains)
    }
  }
}

