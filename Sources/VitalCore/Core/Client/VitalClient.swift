import Foundation
import os.log

let sdk_version = "0.9.4"

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
  
  init?(environment: String, region: String) {
    switch(environment, region) {
      case ("production", "us"):
        self = .production(.us)
      case ("production", "eu"):
        self = .production(.eu)
      case ("sandbox", "us"):
        self = .sandbox(.us)
      case ("sandbox", "eu"):
        self = .sandbox(.eu)
      case ("dev", "us"):
        self = .dev(.us)
      case ("dev", "eu"):
        self = .dev(.eu)
      case (_, _):
        return nil
    }
  }
  
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

@objc public class VitalClient: NSObject {
  
  private let secureStorage: VitalSecureStorage
  let configuration: ProtectedBox<VitalCoreConfiguration>
  let userId: ProtectedBox<UUID>
  
  private static var client: VitalClient?
  private static let clientInitLock = NSLock()
  
  public static var shared: VitalClient {
    clientInitLock.withLock {
      guard let value = client else {
        let newClient = VitalClient()
        Self.client = newClient
        return newClient
      }

      return value
    }
  }

  // @testable
  internal static func setClient(_ client: VitalClient?) {
    clientInitLock.withLock { Self.client = client }
  }
  
  /// Only use this method if you are working from Objc.
  /// Please use the async/await configure method when working from Swift.
  @objc public static func configure(
    apiKey: String,
    environment: String,
    region: String,
    isLogsEnable: Bool
  ) {
    guard let environment = Environment(environment: environment, region: region) else {
      fatalError("Wrong environment and/or region. Acceptable values for environment: dev, sandbox, production. Region: eu, us")
    }

    configure(apiKey: apiKey, environment: environment, configuration: .init(logsEnable: isLogsEnable))
  }

  public static func configure(
    apiKey: String,
    environment: Environment,
    configuration: Configuration = .init()
  ) {
    self.shared.setConfiguration(
      apiKey: apiKey,
      environment: environment,
      configuration: configuration,
      storage: .init(storage: .live),
      apiVersion: "v2"
    )
  }

  // IMPORTANT: The synchronous `configure(3)` is the preferred version over this async one.
  //
  // The async overload is still kept here for source compatibility, because Swift always ignores
  // the non-async overload sharing the same method signature, even if the async version is
  // deprecated.
  @_disfavoredOverload
  public static func configure(
    apiKey: String,
    environment: Environment,
    configuration: Configuration = .init()
  ) async {
    self.shared.setConfiguration(
      apiKey: apiKey,
      environment: environment,
      configuration: configuration,
      storage: .init(storage: .live),
      apiVersion: "v2"
    )
  }

  public static var isConfigured: Bool {
    guard !(self.shared.userId.isNil()) else { return false }
    guard !(self.shared.configuration.isNil()) else { return false }
    return true
  }
  
  @objc(automaticConfigurationWithCompletion:)
  public static func automaticConfiguration(completion: (() -> Void)? = nil) {
    do {
      /// Order is important. `configure` should happen before `setUserId`,
      /// because the latter depends on the former. If we don't do this, the app crash.
      if let payload: VitalCoreSecurePayload = try shared.secureStorage.get(key: core_secureStorageKey) {
        
        /// 1) Set the configuration
        configure(
          apiKey: payload.apiKey,
          environment: payload.environment,
          configuration: payload.configuration
        )
      }

      if let userId: UUID = try shared.secureStorage.get(key: user_secureStorageKey) {
        /// 2) If and only if there's a `userId`, we set it.
        Task {
          await setUserId(userId)
          completion?()
        }
      } else {
        completion?()
      }
    } catch let error {
      completion?()
      /// Bailout, there's nothing else to do here.
      /// (But still try to log it if we have a logger around)
      shared.configuration.value?.logger?.error("Failed to perform automatic configuration: \(error, privacy: .public)")
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
    
    super.init()
  }

  /// **Synchronously** set the configuration and kick off the side effects.
  ///
  /// - important: This cannot not be `async` due to background observer registration
  /// timing requirement by HealthKit in VitalHealthKit. Instead, spawn async tasks if necessary,
  func setConfiguration(
    apiKey: String,
    environment: Environment,
    configuration: Configuration,
    storage: VitalCoreStorage,
    apiVersion: String,
    updateAPIClientConfiguration: (inout APIClient.Configuration) -> Void = { _ in }
  ) {
    
    var logger: Logger?
    
    if configuration.logsEnable {
      logger = Logger(subsystem: "vital", category: "vital-network-client")
    }
    
    logger?.info("VitalClient setup for environment \(String(describing: environment), privacy: .public)")
    
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
      logger?.info("We weren't able to securely store VitalCoreSecurePayload: \(error, privacy: .public)")
    }
    
    let coreConfiguration = VitalCoreConfiguration(
      logger: logger,
      apiVersion: apiVersion,
      apiClient: apiClient,
      environment: environment,
      storage: storage
    )
    
    self.configuration.set(value: coreConfiguration)
  }
  
  private func _setUserId(_ newUserId: UUID) async {
    if configuration.isNil() {
      /// We don't have a configuration at this point, the only realistic thing to do is tell the user to
      fatalError("You need to call `VitalClient.configure` before setting the `userId`")
    }
    
    let configuration = await configuration.get()
    
    do {
      if
        let existingValue: UUID = try secureStorage.get(key: user_secureStorageKey), existingValue != newUserId {
        configuration.storage.clean()
      }
    }
    catch {
      configuration.logger?.info("We weren't able to get the stored userId VitalCoreSecurePayload: \(error, privacy: .public)")
    }
    
    self.userId.set(value: newUserId)
    
    do {
      try secureStorage.set(value: newUserId, key: user_secureStorageKey)
    }
    catch {
      configuration.logger?.info("We weren't able to securely store VitalCoreSecurePayload: \(error, privacy: .public)")
    }
  }
  
  @objc public static func setUserId(_ newUserId: UUID) {
    Task {
      await setUserId(newUserId)
    }
  }

  public static func setUserId(_ newUserId: UUID) async {
    await shared._setUserId(newUserId)
  }
  
  public func isUserConnected(to provider: Provider.Slug) async throws -> Bool {
    let userId = await userId.get()
    let storage = await configuration.get().storage
    
    guard storage.isConnectedSourceStored(for: userId, with: provider) == false else {
      return true
    }
    
    let connectedSources: [Provider] = try await self.user.userConnectedSources()
    return connectedSources.contains { $0.slug == provider }
  }
  
  public func checkConnectedSource(for provider: Provider.Slug) async throws {
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
    if self.configuration.isNil() == false {
      await self.configuration.get().storage.clean()
    }
    
    self.secureStorage.clean(key: core_secureStorageKey)
    self.secureStorage.clean(key: user_secureStorageKey)
    
    self.userId.clean()
    self.configuration.clean()
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
