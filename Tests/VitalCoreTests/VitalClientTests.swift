import XCTest
import Mocker

@testable @_spi(VitalSDKInternals) import VitalCore

let environment = Environment.sandbox(.us)
let userId = UUID().uuidString
let apiKey = UUID().uuidString
let apiVersion = "2.0"
let provider = Provider.Slug.strava

class VitalClientTests: XCTestCase {
  let storage = VitalCoreStorage(storage: .debug)
  let secureStorage = VitalSecureStorage(keychain: .debug)
  lazy var client = VitalClient(secureStorage: secureStorage, storage: storage)

  override func setUp() async throws {
    await VitalClient.shared.signOut()
    VitalClient.setClient(client)
  }
  
  func testInitSetsSharedInstance() throws {
    XCTAssertTrue(client === VitalClient.shared)
  }
  
  func testStorageAndCleanUp() async throws {
    storage.storeConnectedSource(for: userId, with: provider)

    /// Ideally we would call `VitalClient.configure(...)`
    /// The issue is that we have no way to inject mocks, therefore we have to rely on `setConfiguration`.
    /// I don't feel particularly happy with this approach. The only reason I know that I should
    /// call `setConfiguration` is because I know the implementation, which sort of defeats the point.
    client.setConfiguration(
      strategy: .apiKey(apiKey, environment),
      configuration: .init(logsEnable: false),
      apiVersion: apiVersion,
      updateAPIClientConfiguration: makeMockApiClient(configuration:)
    )
    
    await VitalClient.setUserId(UUID(uuidString: userId)!)
    
    let securePayload: VitalClientRestorationState? = try? secureStorage.get(key: core_secureStorageKey)
    let storedUserId: String? = try? secureStorage.get(key: user_secureStorageKey)
    
    XCTAssertEqual(securePayload?.configuration.logsEnable, false)
    XCTAssertEqual(securePayload?.apiVersion, apiVersion)
    XCTAssertEqual(securePayload?.strategy, ConfigurationStrategy.apiKey(apiKey, environment))
    
    XCTAssertEqual(storedUserId, userId)
    XCTAssertTrue(
      storage.isConnectedSourceStored(for: userId, with: provider)
    )
    
    await VitalClient.shared.signOut()

    XCTAssertTrue(VitalClient.shared.apiKeyModeUserId.isNil())
    XCTAssertTrue(VitalClient.shared.configuration.isNil())
    
    let nilSecurePayload: VitalClientRestorationState? = try? secureStorage.get(key: core_secureStorageKey)
    let nilStoredUserId: UUID? = try? secureStorage.get(key: user_secureStorageKey)
    
    XCTAssertNil(nilSecurePayload)
    XCTAssertNil(nilStoredUserId)
    
    XCTAssertFalse(
      storage.isConnectedSourceStored(for: userId, with: provider)
    )
  }

  func testAutomaticConfiguration_autoMigrateFromLegacyAPIMode() async throws {
    let _: Void = await withUnsafeContinuation { continuation in
      VitalClient.automaticConfiguration {
        continuation.resume(returning: ())
      }
    }

    let nilConfiguration = VitalClient.shared.configuration.isNil()
    let nilUserId = VitalClient.shared.apiKeyModeUserId.isNil()

    XCTAssertTrue(nilUserId)
    XCTAssertTrue(nilConfiguration)

    let securePayload = VitalClientRestorationState(
      configuration: .init(),
      apiVersion: apiVersion,

      // Payload stored by Legacy API Mode in an earlier release contains `apiKey` and `environment`
      // but not `strategy`.
      apiKey: apiKey,
      environment: environment,
      strategy: nil
    )

    let secureStorage = VitalSecureStorage(keychain: .debug)
    try! secureStorage.set(value: userId, key: user_secureStorageKey)
    try! secureStorage.set(value: securePayload, key: core_secureStorageKey)

    let newClient = VitalClient(secureStorage: secureStorage)
    VitalClient.setClient(newClient)

    let _: Void = await withUnsafeContinuation { continuation in
      VitalClient.automaticConfiguration {
        continuation.resume(returning: ())
      }
    }

    // TEST: Configuration is set
    let configuration = try XCTUnwrap(VitalClient.shared.configuration.value)

    // TEST: Auth Mode is API Key
    XCTAssertEqual(configuration.authMode, .apiKey)

    // TEST: API Key Mode User ID equals to fake user ID
    XCTAssertEqual(VitalClient.shared.apiKeyModeUserId.value?.uuidString, userId)
  }

  func testAutomaticConfiguration_userJWTMode() async throws {
    let _: Void = await withUnsafeContinuation { continuation in
      VitalClient.automaticConfiguration {
        continuation.resume(returning: ())
      }
    }

    let nilConfiguration = VitalClient.shared.configuration.isNil()
    let nilUserId = VitalClient.shared.apiKeyModeUserId.isNil()

    XCTAssertTrue(nilUserId)
    XCTAssertTrue(nilConfiguration)

    let securePayload = VitalClientRestorationState(
      configuration: .init(),
      apiVersion: apiVersion,
      apiKey: nil,
      environment: nil,
      strategy: .jwt(environment)
    )

    let secureStorage = VitalSecureStorage(keychain: .debug)
    try! secureStorage.set(value: userId, key: user_secureStorageKey)
    try! secureStorage.set(value: securePayload, key: core_secureStorageKey)

    let newClient = VitalClient(secureStorage: secureStorage)
    VitalClient.setClient(newClient)

    let _: Void = await withUnsafeContinuation { continuation in
      VitalClient.automaticConfiguration {
        continuation.resume(returning: ())
      }
    }

    // TEST: Configuration is set
    let configuration = try XCTUnwrap(VitalClient.shared.configuration.value)

    // TEST: Auth Mode is JWT
    XCTAssertEqual(configuration.authMode, .userJwt)

    // TEST: API Key Mode User ID is nil
    XCTAssertNil(VitalClient.shared.apiKeyModeUserId.value)
  }

  func testAutoConfigurationDoesNotFailWithUserIdWithoutConfiguration() async {
    let _: Void = await withUnsafeContinuation { continuation in
      VitalClient.automaticConfiguration {
        continuation.resume(returning: ())
      }
    }

    XCTAssertNil(VitalClient.shared.configuration.value)
    XCTAssertNil(VitalClient.shared.apiKeyModeUserId.value)

    // TEST: Set userId only. `automaticConfiguration` should skip setting it,
    // since a configuration is not present.
    let secureStorage = VitalSecureStorage(keychain: .debug)
    try! secureStorage.set(value: userId, key: user_secureStorageKey)

    let newClient = VitalClient(secureStorage: secureStorage)
    VitalClient.setClient(newClient)

    let _: Void = await withUnsafeContinuation { continuation in
      VitalClient.automaticConfiguration {
        continuation.resume(returning: ())
      }
    }

    XCTAssertNil(VitalClient.shared.configuration.value)
    XCTAssertNil(VitalClient.shared.apiKeyModeUserId.value)
  }
  
  func testStorageIsCleanedUpOnUserIdChange() async {
    storage.storeConnectedSource(for: userId, with: provider)
    
    client.setConfiguration(
      strategy: .apiKey(apiKey, environment),
      configuration: .init(logsEnable: false),
      apiVersion: apiVersion,
      updateAPIClientConfiguration: makeMockApiClient(configuration:)
    )
    
    await VitalClient.setUserId(UUID(uuidString: userId)!)
    
    await VitalClient.setUserId(UUID())
    
    let isConnected = storage.isConnectedSourceStored(for: userId, with: provider)
    XCTAssertFalse(isConnected)
  }
  
  func testProviderIsStored() async {
    storage.storeConnectedSource(for: userId, with: provider)

    client.setConfiguration(
      strategy: .apiKey(apiKey, environment),
      configuration: .init(logsEnable: false),
      apiVersion: apiVersion,
      updateAPIClientConfiguration: makeMockApiClient(configuration:)
    )
    
    await VitalClient.setUserId(UUID(uuidString: userId)!)
    
    let isConnected = try! await VitalClient.shared.isUserConnected(to: provider)
    XCTAssertTrue(isConnected)
  }

  func testConfigurationBackwardCompatibility() throws {
    let decoder = JSONDecoder()

    let payload = """
    {"logsEnable": true}
    """
    let config = try decoder.decode(VitalClient.Configuration.self, from: payload.data(using: .utf8)!)
    XCTAssertTrue(config.logsEnable)
    XCTAssertFalse(config.localDebug)

    let payload2 = """
    {"logsEnable": true, "localDebug": true}
    """
    let config2 = try decoder.decode(VitalClient.Configuration.self, from: payload2.data(using: .utf8)!)
    XCTAssertTrue(config2.logsEnable)
    XCTAssertTrue(config2.localDebug)
  }

  func testRestorationStateBackwardCompatibility() throws {
    let decoder = JSONDecoder()

    let payload = """
    {"configuration": {"logsEnable": true}, "apiVersion": "v2", "apiKey": "1234", "environment": {"dev": {"_0": "us"}}}
    """
    let state = try decoder.decode(VitalClientRestorationState.self, from: payload.data(using: .utf8)!)
    XCTAssertEqual(
      state,
      VitalClientRestorationState(configuration: .init(logsEnable: true), apiVersion: "v2", apiKey: "1234", environment: .dev(.us), strategy: nil)
    )
    XCTAssertEqual(try state.resolveStrategy(), .apiKey("1234", .dev(.us)))

    let payload2 = """
    {"configuration": {"logsEnable": true}, "apiVersion": "v2", "apiKey": "", "environment": null, "strategy": {"apiKey": {"_0": "2345", "_1": {"dev": {"_0": "eu"}}}}}
    """
    let state2 = try decoder.decode(VitalClientRestorationState.self, from: payload2.data(using: .utf8)!)
    XCTAssertEqual(
      state2,
      VitalClientRestorationState(configuration: .init(logsEnable: true), apiVersion: "v2", apiKey: "", environment: nil, strategy: .apiKey("2345", .dev(.eu)))
    )
    XCTAssertEqual(try state2.resolveStrategy(), .apiKey("2345", .dev(.eu)))

    let payload3 = """
    {"configuration": {"logsEnable": true}, "apiVersion": "v2", "apiKey": "", "environment": null, "strategy": {"jwt": {"_0": {"sandbox": {"_0": "eu"}}}}}
    """
    let state3 = try decoder.decode(VitalClientRestorationState.self, from: payload3.data(using: .utf8)!)
    XCTAssertEqual(
      state3,
      VitalClientRestorationState(configuration: .init(logsEnable: true), apiVersion: "v2", apiKey: "", environment: nil, strategy: .jwt(.sandbox(.eu)))
    )
    XCTAssertEqual(try state3.resolveStrategy(), .jwt(.sandbox(.eu)))
  }
}
