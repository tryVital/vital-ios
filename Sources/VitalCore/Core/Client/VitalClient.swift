import Foundation
import os.log

let sdk_version = "0.3.6"

struct Credentials: Equatable, Hashable {
  let apiKey: String
  let environment: Environment
}

struct VitalCoreConfiguration {
  var logger: Logger? = nil
  let apiVersion: String
  let apiClient: APIClient
  let environment: Environment
  let storage: VitalCoreStorage
}

struct VitalCoreSecurePayload: Codable {
  let configuration: VitalClient.Configuration
  let apiVersion: String
  let apiKey: String
  let environment: Environment
}

public enum Environment: Equatable, Hashable, Codable {
  public enum Region: String, Equatable, Hashable, Codable {
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

let core_secureStorageKey: String = "core_secureStorageKey"
let user_secureStorageKey: String = "user_secureStorageKey"

public let health_secureStorageKey: String = "health_secureStorageKey"

public class VitalClient {
  
  private let secureStorage: VitalSecureStorage
  let configuration: ProtectedBox<VitalCoreConfiguration>
  let userId: ProtectedBox<UUID>
  
  private static var client: VitalClient?
  
  public static var shared: VitalClient {
    guard let value = client else {
      let newClient = VitalClient()
      return newClient
    }
    
    return value
  }
  
  public static func configure(
    apiKey: String,
    environment: Environment,
    configuration: Configuration = .init()
  ) async {
    await self.shared.setConfiguration(
      apiKey: apiKey,
      environment: environment,
      configuration: configuration,
      storage: .init(storage: .live),
      apiVersion: "v2"
    )
  }
  
  public static func automaticConfiguration() async {
    do {
      /// Order is important. `configure` should happen before `setUserId`,
      /// because the latter depends on the former. If we don't do this, the app crash.
      if let payload: VitalCoreSecurePayload = try shared.secureStorage.get(key: core_secureStorageKey) {
        
        /// 1) Set the configuration
        await configure(
          apiKey: payload.apiKey,
          environment: payload.environment,
          configuration: payload.configuration
        )
      }
      
      if let userId: UUID = try shared.secureStorage.get(key: user_secureStorageKey) {
        /// 2) If and only if there's a `userId`, we set it.
        await setUserId(userId)
      }
    }
    catch {
      /// Bailout, there's nothing else to do here.
    }
  }
  
  init(
    secureStorage: VitalSecureStorage = .init(keychain: .live),
    configuration: ProtectedBox<VitalCoreConfiguration> = .init(),
    userId: ProtectedBox<UUID> = .init()
  ) {
    self.secureStorage = secureStorage
    self.configuration = configuration
    self.userId = userId
    
    VitalClient.client = self
  }
  
  func setConfiguration(
    apiKey: String,
    environment: Environment,
    configuration: Configuration,
    storage: VitalCoreStorage,
    apiVersion: String,
    updateAPIClientConfiguration: (inout APIClient.Configuration) -> Void = { _ in }
  ) async {
    
    var logger: Logger?
    
    if configuration.logsEnable {
      logger = Logger(subsystem: "vital", category: "vital-network-client")
    }
    
    logger?.info("VitalClient setup for environment \(String(describing: environment))")
    
    let apiClientDelegate = VitalClientDelegate(
      environment: environment,
      logger: logger,
      apiKey: apiKey
    )
    
    let apiClient = APIClient(baseURL: URL(string: environment.host)!) { configuration in
      configuration.delegate = apiClientDelegate
      
      updateAPIClientConfiguration(&configuration)
      
      let encoder = JSONEncoder()
      encoder.dateEncodingStrategy = .iso8601
      encoder.keyEncodingStrategy = .convertToSnakeCase
      
      let decoder = JSONDecoder()
      decoder.keyDecodingStrategy = .convertFromSnakeCase
      decoder.dateDecodingStrategy = .iso8601
      
      configuration.encoder = encoder
      configuration.decoder = decoder
    }
    
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
      logger?.info("We weren't able to securely store VitalCoreSecurePayload: \(error.localizedDescription)")
    }
    
    let coreConfiguration = VitalCoreConfiguration(
      logger: logger,
      apiVersion: apiVersion,
      apiClient: apiClient,
      environment: environment,
      storage: storage
    )
    
    await self.configuration.set(value: coreConfiguration)
  }
  
  private func _setUserId(_ newUserId: UUID) async {
    if await configuration.isNil() {
      /// We don't have a configuration at this point, the only realistic thing to do is tell the user to
      fatalError("You need to call `VitalClient.configuration` before setting the `userId`")
    }
    
    let configuration = await configuration.get()
    
    do {
      if
        let existingValue: UUID = try secureStorage.get(key: user_secureStorageKey), existingValue != newUserId {
        configuration.storage.clean()
      }
    }
    catch {
      configuration.logger?.info("We weren't able to get the stored userId VitalCoreSecurePayload: \(error.localizedDescription)")
    }
    
    await self.userId.set(value: newUserId)
    
    do {
      try secureStorage.set(value: newUserId, key: user_secureStorageKey)
    }
    catch {
      configuration.logger?.info("We weren't able to securely store VitalCoreSecurePayload: \(error.localizedDescription)")
    }
  }
  
  public static func setUserId(_ newUserId: UUID) async {
    await shared._setUserId(newUserId)
  }
  
  public func isUserConnected(to provider: Provider) async throws -> Bool {
    let userId = await userId.get()
    let storage = await configuration.get().storage
    
    guard storage.isConnectedSourceStored(for: userId, with: provider) == false else {
      return true
    }
    
    let connectedSources = try await self.user.userConnectedSources()
    return connectedSources.contains(provider)
  }
  
  public func checkConnectedSource(for provider: Provider) async throws {
    let userId = await userId.get()
    let storage = await configuration.get().storage
    
    if try await isUserConnected(to: provider) == false {
      try await self.link.createConnectedSource(userId, provider: provider)
    }
    
    storage.storeConnectedSource(for: userId, with: provider)
  }
  
  public func cleanUp() async {
    /// Here we remove the following:
    /// 1) Anchor values we are storing for each `HKSampleType`.
    /// 2) Stage for each `HKSampleType`.
    ///
    /// We might be able to derive 2) from 1)?
    ///
    /// We need to check this first, otherwise it will suspend until a configuration is set
    if await self.configuration.isNil() == false {
      await self.configuration.get().storage.clean()
    }
    
    self.secureStorage.clean(key: core_secureStorageKey)
    self.secureStorage.clean(key: health_secureStorageKey)
    self.secureStorage.clean(key: user_secureStorageKey)
    
    await self.userId.clean()
    await self.configuration.clean()
  }
}

public extension VitalClient {
  struct Configuration: Codable {
    public let logsEnable: Bool
    
    public init(
      logsEnable: Bool = false
    ) {
      self.logsEnable = logsEnable
    }
  }
}
