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

  func testAutomaticConfiguration_autoMigrateFromLegacyAPIMode() async throws {
    let _: Void = await withUnsafeContinuation { continuation in
      VitalClient.automaticConfiguration {
        continuation.resume(returning: ())
      }
    }

    let nilConfiguration = VitalClient.shared.configuration.isNil()

    XCTAssertNil(VitalClient.currentUserId)
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
    try! secureStorage.set(value: userId, key: legacyUserIdKey)
    try! secureStorage.set(value: securePayload, key: legacyRestorationStateKey)

    let newClient = VitalClient(secureStorage: secureStorage)
    VitalClient.setClient(newClient)

    let _: Void = await withUnsafeContinuation { continuation in
      VitalClient.automaticConfiguration {
        continuation.resume(returning: ())
      }
    }

    // TEST: Auth Mode is API Key
    XCTAssertEqual(VitalClient.status, [.configured, .signedIn, .useApiKey])

    // TEST: User ID equals to fake user ID
    XCTAssertEqual(VitalClient.currentUserId, userId)
  }

  func testAutomaticConfiguration_userJWTMode() async throws {
    let _: Void = await withUnsafeContinuation { continuation in
      VitalClient.automaticConfiguration {
        continuation.resume(returning: ())
      }
    }

    let nilConfiguration = VitalClient.shared.configuration.isNil()

    XCTAssertNil(VitalClient.currentUserId)
    XCTAssertTrue(nilConfiguration)

    let securePayload = VitalClientRestorationState(
      configuration: .init(),
      apiVersion: apiVersion,
      apiKey: nil,
      environment: nil,
      strategy: .jwt(environment)
    )

    let secureStorage = VitalSecureStorage(keychain: .debug)
    try! secureStorage.set(value: userId, key: legacyUserIdKey)
    try! secureStorage.set(value: securePayload, key: legacyRestorationStateKey)

    let newClient = VitalClient(secureStorage: secureStorage)
    VitalClient.setClient(newClient)

    let _: Void = await withUnsafeContinuation { continuation in
      VitalClient.automaticConfiguration {
        continuation.resume(returning: ())
      }
    }

    // TEST: Auth Mode is JWT
    XCTAssertEqual(VitalClient.status, [.configured, .signedIn, .useSignInToken])

    // TEST: User ID equals to fake user ID
    XCTAssertEqual(VitalClient.currentUserId, userId)
  }

  func testAutoConfigurationDoesNotFailWithUserIdWithoutConfiguration() async {
    let _: Void = await withUnsafeContinuation { continuation in
      VitalClient.automaticConfiguration {
        continuation.resume(returning: ())
      }
    }

    XCTAssertNil(VitalClient.shared.configuration.value)

    // TEST: Set userId only. `automaticConfiguration` should skip setting it,
    // since a configuration is not present.
    let secureStorage = VitalSecureStorage(keychain: .debug)
    try! secureStorage.set(value: userId, key: legacyUserIdKey)

    let newClient = VitalClient(secureStorage: secureStorage)
    VitalClient.setClient(newClient)

    let _: Void = await withUnsafeContinuation { continuation in
      VitalClient.automaticConfiguration {
        continuation.resume(returning: ())
      }
    }

    XCTAssertNil(VitalClient.shared.configuration.value)
    XCTAssertNil(VitalClient.currentUserId)
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
