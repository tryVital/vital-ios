import Foundation
import os.log

struct Credentials: Equatable, Hashable {
  let apiKey: String
  let environment: Environment
}

struct VitalCoreConfiguration {
  var logger: Logger? = nil
  let apiVersion: String
  let apiClient: APIClient
  let environment: Environment
  let automaticConfiguration: Bool
}

struct VitalCoreSecurePayload: Codable {
  let configuration: VitalClient.Configuration
  let apiVersion: String
  let apiKey: String
  let environment: Environment
}

public enum Environment: Equatable, Hashable, Codable {
  public enum Region: Equatable, Hashable, Codable {
    case eu
    case us
    
    var name: String {
      switch self {
        case .eu:
          return "eu"
        case .us:
          return "us"
      }
    }
  }
  
  case dev(Region)
  case sandbox(Region)
  case production(Region)
  
  var host: String {
    switch self {
      case .dev(.eu):
        return "https://api.dev.eu.tryvital.io"
      case .dev(.us):
        return "https://api.dev.tryvital.io"
      case .sandbox(.eu):
        return "https://api.sandbox.eu.tryvital.io"
      case .sandbox(.us):
        return "https://api.sandbox.tryvital.io"
      case .production(.eu):
        return "https://api.eu.tryvital.io"
      case .production(.us):
        return "https://api.tryvital.io"
    }
  }
  
  var name: String {
    switch self {
      case .dev:
        return "dev"
      case .sandbox:
        return "sandbox"
      case .production:
        return "production"
    }
  }
  
  var region: Region {
    switch self {
      case .dev(let region):
        return region
      case .sandbox(let region):
        return region
      case .production(let region):
        return region
    }
  }
}

private let core_secureStorageKey: String = "core_secureStorageKey"
private let user_secureStorageKey: String = "user_secureStorageKey"

public let health_secureStorageKey: String = "health_secureStorageKey"

public class VitalClient {
  
  private let storage: VitalCoreStorage = .init()
  private let secureStorage: VitalSecureStorage = .init()
  
  let dateFormatter = ISO8601DateFormatter()
  
  var configuration: ProtectedBox<VitalCoreConfiguration> = .init()
  var userId: ProtectedBox<UUID> = .init()
  
  public static var shared: VitalClient {
    return client
  }
  
  private static var client: VitalClient = .init()
  
  public static func configure(
    apiKey: String,
    environment: Environment,
    configuration: Configuration = .init()
  ) {
    Task.detached(priority: .high) {
      await self.client.setConfiguration(
        apiKey: apiKey,
        environment: environment,
        configuration: configuration
      )
    }
  }
  
  public static func automaticConfiguration() {
    Task.detached(priority: .high) {
      do {
        let secureStorage = VitalSecureStorage()
        if let payload: VitalCoreSecurePayload = try secureStorage.get(key: core_secureStorageKey) {
          configure(
            apiKey: payload.apiKey,
            environment: payload.environment,
            configuration: payload.configuration
          )
        }
        
        if let userId: UUID = try secureStorage.get(key: user_secureStorageKey) {
          setUserId(userId)
        }
      }
      catch {
        /// Bailout, there's nothing else to do here.
      }
    }
  }
  
  init() {
    /// Empty initialisation, before VitalClient.configure is called
    /// This gives the consumer the flexibility to call `configure` and `setUserId` when they wish
  }
  
  func setConfiguration(
    apiKey: String,
    environment: Environment,
    configuration: Configuration,
    storage: VitalCoreStorage = .init(),
    apiVersion: String = "v2"
  ) async {
    var logger: Logger?
    
    if configuration.logsEnable {
      logger = Logger(subsystem: "vital", category: "vital-network-client")
    }
    
    if configuration.automaticConfiguration {
      let securePayload = VitalCoreSecurePayload(
        configuration: configuration,
        apiVersion: apiVersion,
        apiKey: apiKey,
        environment: environment
      )
      
      do {
        try secureStorage.set(value: securePayload, key: core_secureStorageKey)
      }
      catch {
        logger?.info("We weren't able to securely store VitalCoreSecurePayload: \(error)")
      }
    }
    
    logger?.info("VitalClient setup for environment \(String(describing: environment))")
    
    let apiClientDelegate = VitalClientDelegate(
      environment: environment,
      logger: logger,
      apiKey: apiKey
    )
    
    let apiClient = APIClient(baseURL: URL(string: environment.host)!) { configuration in
      configuration.delegate = apiClientDelegate
      
      let encoder = JSONEncoder()
      encoder.dateEncodingStrategy = .iso8601
      encoder.keyEncodingStrategy = .convertToSnakeCase
      
      let decoder = JSONDecoder()
      decoder.keyDecodingStrategy = .convertFromSnakeCase
      decoder.dateDecodingStrategy = .iso8601
      
      configuration.encoder = encoder
      configuration.decoder = decoder
    }
    
    let coreConfiguration = VitalCoreConfiguration(
      logger: logger,
      apiVersion: apiVersion,
      apiClient: apiClient,
      environment: environment,
      automaticConfiguration: configuration.automaticConfiguration
    )
        
    await self.configuration.set(value: coreConfiguration)
  }
  
  public static func setUserId(_ userId: UUID) {
    Task.detached(priority: .high) {
      await VitalClient.shared.userId.set(value: userId)
      
      let configuration = await VitalClient.shared.configuration.get()
      if configuration.automaticConfiguration {
        let secureStorage = VitalSecureStorage()
        do {
          try secureStorage.set(value: userId, key: user_secureStorageKey)
        }
        catch {
          configuration.logger?.info("We weren't able to securely store VitalCoreSecurePayload: \(error)")
        }
      }
    }
  }
  
  public func checkConnectedSource(for provider: Provider) async throws {
    let userId = await userId.get()
    
    guard storage.isConnectedSourceStored(for: userId, with: provider) == false else {
      return
    }
    
    let connectedSources = try await self.user.userConnectedSources()
    if connectedSources.contains(provider) == false {
      try await self.link.createConnectedSource(userId, provider: provider)
    }
    
    storage.storeConnectedSource(for: userId, with: provider)
  }
  
  public func cleanUp() {
    Task.detached(priority: .high) {
      /// Here we remove the following:
      /// 1) Anchor values we are storing for each `HKSampleType`.
      /// 2) Stage for each `HKSampleType`.
      ///
      /// We might be able to derive 2) from 1)?
      UserDefaults.standard.removePersistentDomain(forName: "tryVital")
      
      try self.secureStorage.clean(key: core_secureStorageKey)
      try self.secureStorage.clean(key: health_secureStorageKey)
      try self.secureStorage.clean(key: user_secureStorageKey)

      await self.userId.clean()
    }
  }
}

public extension VitalClient {
  struct Configuration: Codable {
    public let logsEnable: Bool
    public let automaticConfiguration: Bool

    public init(
      logsEnable: Bool = false,
      automaticConfiguration: Bool = false
    ) {
      self.logsEnable = logsEnable
      self.automaticConfiguration = automaticConfiguration
    }
  }
}
