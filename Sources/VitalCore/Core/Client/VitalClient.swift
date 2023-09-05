import Foundation
import os.log

let sdk_version = "0.10.1"

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
  let authMode: VitalClient.AuthMode
  let jwtAuth: VitalJWTAuth
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

  // @testable
  internal let apiKeyModeUserId: ProtectedBox<UUID>
  
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

  /// Configure the SDK in User JWT mode (No API Key).
  ///
  /// In this mode, your app requests a Vital Sign-In Token **through your backend service**, typically at the same time when
  /// your user sign-ins with your backend service. This allows your backend service to keep the API Key as a private secret.
  public static func configure(
    environment: Environment,
    configuration: Configuration = .init(authMode: .userJwt)
  ) {
    precondition(configuration.authMode == .userJwt)

    self.shared.setConfiguration(
      apiKey: "",
      environment: environment,
      configuration: configuration,
      storage: .init(storage: .live),
      apiVersion: "v2"
    )
  }

  /// Configure the SDK in the legacy API Key mode.
  ///
  /// API Key mode will continue to be supported. But users should plan to migrate to the User JWT mode.
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
    guard !(self.shared.apiKeyModeUserId.isNil()) else { return false }
    guard !(self.shared.configuration.isNil()) else { return false }
    return true
  }
  
  @objc(automaticConfigurationWithCompletion:)
  public static func automaticConfiguration(completion: (() -> Void)? = nil) {
    do {
      /// Order is important. `configure` should happen before `setUserId`,
      /// because the latter depends on the former. If we don't do this, the app crash.
      if let payload: VitalCoreSecurePayload = try shared.secureStorage.get(key: core_secureStorageKey) {
        
        switch payload.configuration.authMode {
        case .apiKey:
          /// 1) Set the configuration
          configure(
            apiKey: payload.apiKey,
            environment: payload.environment,
            configuration: payload.configuration
          )

          if let userId: UUID = try shared.secureStorage.get(key: user_secureStorageKey) {
            /// 2) If and only if there's a `userId`, we set it.
            shared._setUserId(userId)
          }

        case .userJwt:
          configure(
            environment: payload.environment,
            configuration: payload.configuration
          )

          // VitalJWTAuth self-manages its state persistence, including user ID.
          break
        }
      }

      completion?()
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
    self.apiKeyModeUserId = userId
    
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

    let authStrategy: VitalClientAuthStrategy

    switch configuration.authMode {
    case .apiKey:
      authStrategy = .apiKey(apiKey)
    case .userJwt:
      authStrategy = .jwt(VitalJWTAuth.live)
    }

    let apiClientDelegate = VitalClientDelegate(
      environment: environment,
      logger: logger,
      authStrategy: authStrategy
    )

    let apiClient = makeClient(environment: environment, delegate: apiClientDelegate)
    
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
      storage: storage,
      authMode: configuration.authMode,
      jwtAuth: VitalJWTAuth.live
    )
    
    self.configuration.set(value: coreConfiguration)
  }

  public func signIn(_ rawToken: String) async throws {
    let configuration = await configuration.get()

    guard configuration.authMode == .userJwt else {
      fatalError("signIn(_:) is incompatible with Vital SDK in Legacy API Key mode")
    }

    try await configuration.jwtAuth.signIn(rawToken)
  }

  private func _setUserId(_ newUserId: UUID) {
    guard let configuration = configuration.value else {
      /// We don't have a configuration at this point, the only realistic thing to do is tell the user to
      fatalError("You need to call `VitalClient.configure` before setting the `userId`")
    }

    guard configuration.authMode == .apiKey else {
      fatalError("setUserId(_:) is incompatible with Vital SDK in User JWT mode")
    }

    do {
      if
        let existingValue: UUID = try secureStorage.get(key: user_secureStorageKey), existingValue != newUserId {
        configuration.storage.clean()
      }
    }
    catch {
      configuration.logger?.info("We weren't able to get the stored userId VitalCoreSecurePayload: \(error, privacy: .public)")
    }
    
    self.apiKeyModeUserId.set(value: newUserId)
    
    do {
      try secureStorage.set(value: newUserId, key: user_secureStorageKey)
    }
    catch {
      configuration.logger?.info("We weren't able to securely store VitalCoreSecurePayload: \(error, privacy: .public)")
    }
  }

  @objc(signInWithToken:completion:)
  public static func objc_signIn(_ rawToken: String, completion: @escaping (Error?) -> Void) {
    Task {
      do {
        try await shared.signIn(rawToken)
        completion(nil)
      } catch let error {
        completion(error)
      }
    }
  }

  @nonobjc public static func signIn(_ rawToken: String) async throws {
    try await shared.signIn(rawToken)
  }

  @objc(setUserId:) public static func objc_setUserId(_ newUserId: UUID) {
    shared._setUserId(newUserId)
  }

  @nonobjc public static func setUserId(_ newUserId: UUID) async {
    shared._setUserId(newUserId)
  }

  
  public func isUserConnected(to provider: Provider.Slug) async throws -> Bool {
    let userId = try await getUserId()
    let storage = await configuration.get().storage
    
    guard storage.isConnectedSourceStored(for: userId, with: provider) == false else {
      return true
    }
    
    let connectedSources: [Provider] = try await self.user.userConnectedSources()
    return connectedSources.contains { $0.slug == provider }
  }
  
  public func checkConnectedSource(for provider: Provider.Slug) async throws {
    let userId = try await getUserId()
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
    
    self.apiKeyModeUserId.clean()
    self.configuration.clean()
  }

  internal func getUserId() async throws -> String {
    let configuration = await configuration.get()
    switch configuration.authMode {
    case .apiKey:
      return await apiKeyModeUserId.get().uuidString

    case .userJwt:
      // In User JWT mode, we need not wait for user ID to be set.
      // VitalUserJWT will lazy load the authenticated user from Keychain on first access.
      return try await configuration.jwtAuth.userContext().userId
    }
  }
}

public extension VitalClient {
  enum AuthMode: String, Codable {
    case apiKey
    case userJwt
  }

  struct Configuration: Codable {
    public let logsEnable: Bool
    public let authMode: AuthMode
    
    public init(
      logsEnable: Bool = false,
      authMode: AuthMode = .apiKey
    ) {
      self.logsEnable = logsEnable
      self.authMode = authMode
    }
  }
}
