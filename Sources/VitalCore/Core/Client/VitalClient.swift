import Foundation
import os.log
import Combine

struct Credentials: Equatable, Hashable {
  let apiKey: String
  let environment: Environment
}

@_spi(VitalSDKInternals)
public struct VitalCoreConfiguration {
  public let apiVersion: String
  let apiClient: APIClient
  public let environment: Environment
  public let authMode: VitalClient.AuthMode
}

struct VitalClientRestorationState: Equatable, Codable {
  let configuration: VitalClient.Configuration
  let apiVersion: String

  // Backward compatibility with Legacy API Key mode
  let apiKey: String?
  let environment: Environment?

  // Nullable for compatibility
  let strategy: ConfigurationStrategy?

  func resolveStrategy() throws -> ConfigurationStrategy {
    if let strategy = strategy {
      return strategy
    }

    if let apiKey = apiKey, let environment = environment {
      return .apiKey(apiKey, environment)
    }

    throw DecodingError.dataCorrupted(
      .init(codingPath: [], debugDescription: "persisted SDK configuration seems corrupted")
    )
  }
}

enum ConfigurationStrategy: Hashable, Codable {
  case apiKey(String, Environment)
  case jwt(Environment)

  var environment: Environment {
    switch self {
    case let .apiKey(_, environment):
      return environment
    case let .jwt(environment):
      return environment
    }
  }
}

public enum Environment: Equatable, Hashable, Codable, CustomStringConvertible, Sendable {
  public enum Region: String, Equatable, Hashable, Codable, Sendable {
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

  case local(Region)

  init?(environment: String, region: String) {
    switch(environment, region) {
    case ("production", "us"), ("prd", "us"):
      self = .production(.us)
    case ("production", "eu"), ("prd", "eu"):
      self = .production(.eu)
    case ("sandbox", "us"), ("stg", "us"):
      self = .sandbox(.us)
    case ("sandbox", "eu"), ("stg", "eu"):
      self = .sandbox(.eu)
    case ("dev", "us"):
      self = .dev(.us)
    case ("dev", "eu"):
      self = .dev(.eu)
    case ("local", "eu"):
      self = .local(.eu)
    case ("local", "eu"):
      self = .local(.eu)
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
      case .local:
        return "http://localhost:8000"
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
      case .local:
        return "local"
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
      case .local(let region):
        return region
    }
  }

  public var description: String {
    "\(name) - \(region.name)"
  }
}

let core_secureStorageKey: String = "core_secureStorageKey"
let user_secureStorageKey: String = "user_secureStorageKey"

@_spi(VitalSDKInternals)
public let health_secureStorageKey: String = "health_secureStorageKey"

public enum AuthenticateRequest {
  case apiKey(key: String, userId: String, Environment)
  case signInToken(rawToken: String)
}

@objc public class VitalClient: NSObject {
  public static let sdkVersion = "1.3.2"
  
  private let secureStorage: VitalSecureStorage

  @_spi(VitalSDKInternals)
  public let configuration: ProtectedBox<VitalCoreConfiguration>

  let jwtAuth: VitalJWTAuth

  // @testable
  internal var storage: VitalCoreStorage

  // Moments that would materially affect `VitalClient.Type.status`.
  let statusDidChange = PassthroughSubject<Void, Never>()

  // @testable
  internal let apiKeyModeUserId: ProtectedBox<UUID>

  private static var client: VitalClient?
  private static let clientInitLock = NSLock()
  private static let automaticConfigurationLock = NSLock()
  private var cancellables: Set<AnyCancellable> = []

  // Get: runSignoutTasks()
  // Set: registerSignoutTask()
  private var signoutTasks: [@Sendable () async -> Void] = []

  private static let identifyParkingLot = ParkingLot()

  public static var shared: VitalClient {
    let sharedClient = sharedNoAutoConfig

    // Try to auto-configure the SDK whenever a customer gets a reference to `VitalClient`.
    // This is a no-op when the SDK is in a configured state.
    automaticConfiguration()

    return sharedClient
  }

  internal static var sharedNoAutoConfig: VitalClient {
    let sharedClient = clientInitLock.withLock {
      guard let value = client else {
        let newClient = VitalClient()
        Self.client = newClient
        Self.bind(newClient, jwtAuth: VitalJWTAuth.live)
        return newClient
      }

      return value
    }

    return sharedClient
  }

  // @testable
  internal static func setClient(_ client: VitalClient?) {
    clientInitLock.withLock { Self.client = client }
  }

  @_spi(VitalSDKInternals)
  public func registerSignoutTask(_ action: @Sendable @escaping () async -> Void) {
    Self.clientInitLock.withLock {
      signoutTasks.append(action)
    }
  }

  private func runSignoutTasks() async {
    let tasks = Self.clientInitLock.withLock { signoutTasks }

    await withTaskGroup(of: Void.self) { group in
      for task in tasks {
        group.addTask(priority: .userInitiated) { await task() }
      }
    }
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

    self.shared.setConfiguration(
      strategy: .apiKey(apiKey, environment),
      configuration: Configuration(),
      apiVersion: "v2"
    )
  }


  /// Identify your user to the Vital Mobile SDK with an external user identifier from your system.
  ///
  /// This is _external_ with respect to the SDK. From your perspective, this would be your _internal_ user identifier.
  ///
  /// If the identified external user is not what the SDK has last seen, or has last successfully signed-in:
  /// 1. The SDK calls your supplied `fetchSignInToken` closure.
  /// 2. Your closure obtains a Vital Sign-In Token **from your backend service** and returns it.
  /// 3. The SDK performs the following actions:
  ///
  /// | SDK Signed-In User | The supplied Sign-In Token | Outcome |
  /// | ------ | ------ | ------ |
  /// | User A | User B | Sign out user A, then Sign in user B |
  /// | User A | User A | No-op |
  /// | None | User A | Sign In user A |
  ///
  /// Your `fetchSignInToken` can throw CancellationError to abort the identify operation.
  ///
  /// You should identify at regular and signficant moments in your app user lifecycle to ensure that it stays in sync with
  /// the Vital Mobile SDK user state. For example:
  ///
  /// 1. Identify your user after you signed in a new user.
  /// 2. Identify your user again after you have reloaded user state from persistent storage (e.g. Keychain or UserDefaults) post app launch.
  ///
  /// You can query the current identified user through `VitalClient.identifiedExternalUser`.
  ///
  /// ## Notes on migrating from `signIn(withRawToken:configuration:)`
  ///
  /// `identifyExternalUser` does not perform any action or `signOut()` when the Sign-In Token you supplied belongs
  /// to the already signed-in Vital User — regardless of whether the sign-in happened prior to or after the introduction of
  /// `identifyExternalUser`.
  ///
  /// Because of this behaviour, you can migrate by simply replacing `signIn(...)` with `identifyExternalUser(...)`.
  /// There is no precaution in SDK State — e.g., the Health SDK data sync state — being unintentionally reset.
  public static func identifyExternalUser(
    _ externalUserId: String,
    authenticate: @Sendable (_ externalUserId: String) async throws -> AuthenticateRequest
  ) async throws {

    // Only one `identify` is allowed to run at any given time.
    try await identifyParkingLot.semaphore.acquire()
    defer { identifyParkingLot.semaphore.release() }

    let currentExternalUserId = SDKStartupParamsStorage.live.get()?.externalUserId

    VitalLogger.core.info("input=<\(externalUserId)> current=<\(currentExternalUserId ?? "nil")>", source: "Identify")

    guard currentExternalUserId != externalUserId else { return }

    let request = try await authenticate(externalUserId)

    switch request {
    case let .apiKey(key, userId, environment):
      let status = self.status

      if !status.contains(.configured) {
        self.shared.setConfiguration(
          strategy: .apiKey(key, environment),
          configuration: Configuration(),
          apiVersion: "v2"
        )
      }

      if status.contains(.signedIn), currentUserId?.lowercased() != userId.lowercased() {
        await shared.signOut()
      }

      self.shared._setUserId(UUID(uuidString: userId)!)

    case let .signInToken(rawToken):
        do {
          try await Self._signIn(withRawToken: rawToken)

        } catch VitalJWTSignInError.alreadySignedIn {
          // Sign-out the current user, then sign-in again.
          await shared.signOut()
          try await Self._signIn(withRawToken: rawToken)
        }
    }

    // Sign-in is successful; record the externalUserId.
    try SDKStartupParamsStorage.live.set(SDKStartupParams(externalUserId: externalUserId))

    shared.statusDidChange.send(())
  }


  /// Sign-in the SDK with a User JWT — no API Key is needed.
  ///
  /// In this mode, your app requests a Vital Sign-In Token **through your backend service**, typically at the same time when
  /// your user sign-ins with your backend service. This allows your backend service to keep the API Key as a private secret.
  ///
  /// The environment and region is inferred from the User JWT. You need not specify them explicitly
  @available(*, deprecated, message:"Use `identify(_:authenticate:)`.")
  public static func signIn(
    withRawToken token: String,
    configuration: Configuration = .init()
  ) async throws {
    try await Self._signIn(withRawToken: token, configuration: configuration)
  }

  internal static func _signIn(
    withRawToken token: String,
    configuration: Configuration = .init()
  ) async throws {

    let signInToken = try VitalSignInToken.decode(from: token)
    let claims = try signInToken.unverifiedClaims()
    let jwtAuth = VitalJWTAuth.live

    try await jwtAuth.signIn(with: signInToken)

    // Configure the SDK only if we have signed in successfully.
    self.shared.setConfiguration(
      strategy: .jwt(claims.environment),
      configuration: configuration,
      apiVersion: "v2"
    )

    let configuration = await shared.configuration.get()
    precondition(configuration.authMode == .userJwt)
  }

  /// Configure the SDK in the legacy API Key mode.
  ///
  /// API Key mode will continue to be supported. But users should plan to migrate to the User JWT mode.
  @available(*, deprecated, message:"Use `identify(_:authenticate:)`.")
  public static func configure(
    apiKey: String,
    environment: Environment,
    configuration: Configuration = .init()
  ) {

    self.shared.setConfiguration(
      strategy: .apiKey(apiKey, environment),
      configuration: configuration,
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
      strategy: .apiKey(apiKey, environment),
      configuration: configuration,
      apiVersion: "v2"
    )
  }

  public static var status: Status {
    computeStatus(Self.shared)
  }

  private static func computeStatus(_ client: VitalClient) -> Status {
    var status = Status()

    if let configuration = client.configuration.value {
      status.insert(.configured)

      switch configuration.authMode {
      case .apiKey:
        if self.shared.apiKeyModeUserId.value != nil {
          status.insert(.signedIn)
          status.insert(.useApiKey)
        }

      case .userJwt:
        if shared.jwtAuth.currentUserId != nil {
          status.insert(.signedIn)
          status.insert(.useSignInToken)

          if shared.jwtAuth.pendingReauthentication {
            status.insert(.pendingReauthentication)
          }
        }
      }
    }

    return status
  }

  public static var statusDidChange: AnyPublisher<Void, Never> {
    shared.statusDidChange.eraseToAnyPublisher()
  }

  public static var statuses: AsyncStream<VitalClient.Status> {
    AsyncStream<VitalClient.Status> { continuation in
      continuation.yield(VitalClient.status)

      let cancellable = statusDidChange.sink(
        receiveValue: { continuation.yield(VitalClient.status) }
      )
      continuation.onTermination = { _ in cancellable.cancel() }
    }
  }

  public static var currentUserId: String? {
    if let configuration = self.shared.configuration.value {
      switch configuration.authMode {
      case .apiKey:
        return self.shared.apiKeyModeUserId.value?.uuidString
      case .userJwt:
        return self.shared.jwtAuth.currentUserId
      }
    } else {
      return nil
    }
  }

  /// The last identified external user that is successfully processed by `identifyExternalUser`.
  ///
  /// This is `nil` if you have never used `identifyExternalUser`, or if you have signed out the user explicitly.
  public static var identifiedExternalUser: String? {
    return SDKStartupParamsStorage.live.get()?.externalUserId
  }

  @objc(automaticConfigurationWithCompletion:)
  public static func automaticConfiguration(completion: (() -> Void)? = nil) {
    defer {
      completion?()
    }

    let client = sharedNoAutoConfig

    // Already configured; skip automatic configuration.
    guard client.configuration.isNil() else {
      return
    }

    automaticConfigurationLock.lock()

    defer {
      automaticConfigurationLock.unlock()
      VitalLogger.core.info("postAutoConfig: \(Self.computeStatus(client))", source: "CoreStatus")
    }

    do {
      /// Order is important. `configure` should happen before `setUserId`,
      /// because the latter depends on the former. If we don't do this, the app crash.
      if let restorationState: VitalClientRestorationState = try client.secureStorage.get(key: core_secureStorageKey) {
        
        let strategy = try restorationState.resolveStrategy()

        /// 1) Set the configuration
        client.setConfiguration(
          strategy: strategy,
          configuration: restorationState.configuration,
          apiVersion: "v2"
        )

        if
          case .apiKey = strategy,
          let userId: UUID = try client.secureStorage.get(key: user_secureStorageKey)
        {
          /// 2) If and only if there's a `userId`, we set it.
          ///
          /// Note that this is only applicable to the Legacy API Key mode.
          /// In User JWT mode, user ID is part of the JWT claims, and VitalJWTAuth is fully responsible for its persistence.
          client._setUserId(userId)
        }
      }

    } catch let error {
      /// Bailout, there's nothing else to do here.
      /// (But still try to log it if we have a logger around)
      VitalLogger.core.error("Failed to perform automatic configuration: \(error)")
    }
  }

  private static func bind(_ client: VitalClient, jwtAuth: VitalJWTAuth) {
    // When JWT detects that a user has been deleted, automatically reset the SDK.
    jwtAuth.statusDidChange
      .filter { $0 == .userNoLongerValid }
      .sink { _ in
        Task {
          await client.signOut()
        }
      }
      .store(in: &client.cancellables)

    // Asynchronously log Core SDK status changes
    // NOTE: This must start async. Otherwise, `VitalClient.statuses` will access
    // `VitalClient.shared` while the initialization lock is still held by the caller of
    // `bind()`.
    Task {
      for await status in type(of: client).statuses {
        VitalLogger.core.info("updated: \(status)", source: "CoreStatus")
      }
    }
  }

  init(
    secureStorage: VitalSecureStorage = .init(keychain: .live),
    configuration: ProtectedBox<VitalCoreConfiguration> = .init(),
    userId: ProtectedBox<UUID> = .init(),
    storage: VitalCoreStorage = .init(storage: .live),
    jwtAuth: VitalJWTAuth = .live
  ) {
    self.secureStorage = secureStorage
    self.configuration = configuration
    self.apiKeyModeUserId = userId
    self.storage = storage
    self.jwtAuth = jwtAuth
    
    super.init()
  }

  /// **Synchronously** set the configuration and kick off the side effects.
  ///
  /// - important: This cannot not be `async` due to background observer registration
  /// timing requirement by HealthKit in VitalHealthKit. Instead, spawn async tasks if necessary,
  func setConfiguration(
    strategy: ConfigurationStrategy,
    configuration: Configuration,
    apiVersion: String,
    updateAPIClientConfiguration: (inout APIClient.Configuration) -> Void = { _ in }
  ) {
    
    VitalLogger.core.info("VitalClient setup for environment \(String(describing: strategy.environment))")

    let authMode: VitalClient.AuthMode
    let authStrategy: VitalClientAuthStrategy
    let actualEnvironment: Environment

#if DEBUG
    if configuration.localDebug {
      actualEnvironment = .local(strategy.environment.region)
    } else {
      actualEnvironment = strategy.environment
    }
#else
    actualEnvironment = strategy.environment
#endif

    switch strategy {
    case let .apiKey(key, _):
      authStrategy = .apiKey(key)
      authMode = .apiKey

    case .jwt:
      authStrategy = .jwt(jwtAuth)
      authMode = .userJwt
    }

    let apiClientDelegate = VitalClientDelegate(
      environment: actualEnvironment,
      authStrategy: authStrategy
    )

    let apiClient = makeClient(environment: actualEnvironment, delegate: apiClientDelegate)
    
    let restorationState = VitalClientRestorationState(
      configuration: configuration,
      apiVersion: apiVersion,
      apiKey: nil,
      environment: nil,
      strategy: strategy
    )
    
    do {
      try secureStorage.set(value: restorationState, key: core_secureStorageKey)
    }
    catch {
      VitalLogger.core.info("We weren't able to securely store VitalClientRestorationState: \(error)")
    }
    
    let coreConfiguration = VitalCoreConfiguration(
      apiVersion: apiVersion,
      apiClient: apiClient,
      environment: actualEnvironment,
      authMode: authMode
    )
    
    self.configuration.set(value: coreConfiguration)
    statusDidChange.send(())
  }

  private func _setUserId(_ newUserId: UUID) {

    guard let configuration = configuration.value else {
      /// We don't have a configuration at this point, the only realistic thing to do is tell the user to
      fatalError("You need to call `VitalClient.configure` before setting the `userId`")
    }

    guard configuration.authMode == .apiKey else {
      VitalLogger.core.error("VitalClient.setUserId(_:) is ignored when the SDK is configured by a Vital Sign-In Token.")
      return
    }

    do {
      if
        let existingValue: UUID = try secureStorage.get(key: user_secureStorageKey), existingValue != newUserId {
        self.storage.clean()
      }
    }
    catch {
      VitalLogger.core.info("We weren't able to get the stored userId VitalClientRestorationState: \(error)")
    }
    
    self.apiKeyModeUserId.set(value: newUserId)
    statusDidChange.send(())
    
    do {
      try secureStorage.set(value: newUserId, key: user_secureStorageKey)
    }
    catch {
      VitalLogger.core.info("We weren't able to securely store VitalClientRestorationState: \(error)")
    }
  }

  @objc(setUserId:) public static func objc_setUserId(_ newUserId: UUID) {
    shared._setUserId(newUserId)
  }

  @nonobjc public static func setUserId(_ newUserId: UUID) async {
    shared._setUserId(newUserId)
  }
  
  public func isUserConnected(to provider: Provider.Slug) async throws -> Bool {
    let userId = try await getUserId()
    let storage = self.storage
    
    guard storage.isConnectedSourceStored(for: userId, with: provider) == false else {
      return true
    }
    
    let connectedSources: [UserConnection] = try await self.user.userConnections()
    return connectedSources.contains { $0.slug == provider }
  }
  
  @_spi(VitalSDKInternals)
  public func checkConnectedSource(for provider: Provider.Slug) async throws {
    let userId = try await getUserId()
    try await self.link.createConnectedSource(userId, provider: provider)

    let storage = self.storage
    storage.storeConnectedSource(for: userId, with: provider)
  }

  public func signOut() async {
    VitalLogger.core.info("begin", source: "SignOut")
    defer {
      VitalLogger.core.info("end", source: "SignOut")
    }

    // First make sure all child SDKs have done their cleanup and closed off ALL outstanding work.
    await runSignoutTasks()

    // Then we clear the storage and persistent user session.
    self.storage.clean()
    try? await self.jwtAuth.signOut()
    try? SDKStartupParamsStorage.live.set(nil)

    self.secureStorage.clean(key: core_secureStorageKey)
    self.secureStorage.clean(key: user_secureStorageKey)
    self.secureStorage.clean(key: health_secureStorageKey)

    self.apiKeyModeUserId.clean()
    self.configuration.clean()

    statusDidChange.send(())
  }

  internal func getUserId() async throws -> String {
    /// SDK now attempts automatic configuration on singleton creation to recover API Key +
    /// userID from keychain. (See: `VitalClient.shared`)
    ///
    /// So it is no longer necessary to await on the user ID and configuration.

    guard let configuration = configuration.value else {
      throw VitalClient.Error.notConfigured
    }

    switch configuration.authMode {
    case .apiKey:
      guard let userId = apiKeyModeUserId.value?.uuidString else {
        throw VitalClient.Error.notSignedIn
      }
      return userId

    case .userJwt:
      // In User JWT mode, we need not wait for user ID to be set.
      // VitalUserJWT will lazy load the authenticated user from Keychain on first access.
      return try await jwtAuth.userContext().userId
    }
  }
}

extension VitalClient {
  @_spi(VitalTesting) public static func forceRefreshToken() async throws {
    let configuration = await shared.configuration.get()
    precondition(configuration.authMode == .userJwt)

    try await shared.jwtAuth.refreshToken()
  }
}

public extension VitalClient {
  struct Configuration: Equatable, Codable {
    public var logsEnable: Bool
    public var localDebug: Bool

    public init(
      logsEnable: Bool = false,
      localDebug: Bool = false
    ) {
      self.logsEnable = logsEnable
      self.localDebug = localDebug
    }

    public init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: Self.CodingKeys.self)
      self.logsEnable = try container.decodeIfPresent(Bool.self, forKey: .logsEnable) ?? false
      self.localDebug = try container.decodeIfPresent(Bool.self, forKey: .localDebug) ?? false
    }
  }

  enum AuthMode: String, Codable {
    case apiKey
    case userJwt
  }

  struct Status: OptionSet, CustomStringConvertible {
    /// The SDK has been configured, either through `VitalClient.Type.configure` for the first time,
    /// or through `VitalClient.Type.automaticConfiguration()` where the last auto-saved
    /// configuration has been restored.
    public static let configured = Status(rawValue: 1)

    /// The SDK has an active sign-in.
    public static let signedIn = Status(rawValue: 1 << 1)

    /// The active sign-in was done through an explicitly set target User ID, paired with a Vital API Key.
    /// (through `VitalClient.Type.setUserId(_:)`)
    ///
    /// Not recommended for production apps.
    public static let useApiKey = Status(rawValue: 1 << 2)

    /// The active sign-in is done through a Vital Sign-In Token via `VitalClient.Type.signIn`.
    public static let useSignInToken = Status(rawValue: 1 << 3)

    /// A Vital Sign-In Token sign-in session that is currently on hold, requiring re-authentication using
    /// a new Vital Sign-In Token issued for the same user.
    ///
    /// This generally should not happen, as Vital's identity broker guarantees only to revoke auth
    /// refresh tokens when a user is explicitly deleted, disabled or have their tokens explicitly
    /// revoked.
    public static let pendingReauthentication = Status(rawValue: 1 << 4)

    public let rawValue: Int

    public var description: String {
      var texts: [String] = []
      if self.contains(.configured) {
        texts.append("configured")
      }
      if self.contains(.signedIn) {
        texts.append("signedIn")
      }
      if self.contains(.useApiKey) {
        texts.append("useApiKey")
      }
      if self.contains(.useSignInToken) {
        texts.append("useSignInToken")
      }
      if self.contains(.pendingReauthentication) {
        texts.append("pendingReauthentication")
      }

      if texts.isEmpty {
        return "<not configured>"
      } else {
        return texts.joined(separator: ",")
      }
    }

    public init(rawValue: Int) {
      self.rawValue = rawValue
    }
  }
}

extension VitalClient {
  public enum Error: Swift.Error {
    case notConfigured
    case notSignedIn
  }
}
