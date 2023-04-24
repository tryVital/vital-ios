import XCTest
import Mocker

@testable import VitalCore

let environment = Environment.sandbox(.us)
let userId = UUID()
let apiKey = UUID().uuidString
let apiVersion = "2.0"
let provider = Provider.Slug.strava

class VitalClientTests: XCTestCase {
  let secureStorage = VitalSecureStorage(keychain: .debug)
  lazy var client = VitalClient(secureStorage: secureStorage)

  override func setUp() async throws {
    await VitalClient.shared.cleanUp()
    VitalClient.setClient(client)
  }
  
  func testInitSetsSharedInstance() throws {
    XCTAssertTrue(client === VitalClient.shared)
  }
  
  func testStorageAndCleanUp() async throws {
    let storage = VitalCoreStorage(storage: .debug)
    storage.storeConnectedSource(for: userId, with: provider)

    /// Ideally we would call `VitalClient.configure(...)`
    /// The issue is that we have no way to inject mocks, therefore we have to rely on `setConfiguration`.
    /// I don't feel particularly happy with this approach. The only reason I know that I should
    /// call `setConfiguration` is because I know the implementation, which sort of defeats the point.
    client.setConfiguration(
      apiKey: apiKey,
      environment: environment,
      configuration: .init(logsEnable: false),
      storage: storage,
      apiVersion: apiVersion,
      updateAPIClientConfiguration: makeMockApiClient(configuration:)
    )
    
    await VitalClient.setUserId(userId)
    
    let securePayload: VitalCoreSecurePayload? = try? secureStorage.get(key: core_secureStorageKey)
    let storedUserId: UUID? = try? secureStorage.get(key: user_secureStorageKey)
    
    XCTAssertEqual(securePayload?.configuration.logsEnable, false)
    XCTAssertEqual(securePayload?.apiVersion, apiVersion)
    XCTAssertEqual(securePayload?.apiKey, apiKey)
    XCTAssertEqual(securePayload?.environment, environment)
    
    XCTAssertEqual(storedUserId, userId)
    XCTAssertTrue(
      storage.isConnectedSourceStored(for: userId, with: provider)
    )
    
    await VitalClient.shared.cleanUp()
    
    let inMemoryStoredUser = VitalClient.shared.userId.isNil()
    let inMemoryStoredConfiguration = VitalClient.shared.configuration.isNil()
    
    XCTAssertTrue(inMemoryStoredUser)
    XCTAssertTrue(inMemoryStoredConfiguration)
    
    let nilSecurePayload: VitalCoreSecurePayload? = try? secureStorage.get(key: core_secureStorageKey)
    let nilStoredUserId: UUID? = try? secureStorage.get(key: user_secureStorageKey)
    
    XCTAssertNil(nilSecurePayload)
    XCTAssertNil(nilStoredUserId)
    
    XCTAssertFalse(
      storage.isConnectedSourceStored(for: userId, with: provider)
    )
  }

  func testAutoUserIdConfiguration() async {
    let _: Void = await withCheckedContinuation { continuation in
      VitalClient.automaticConfiguration {
        continuation.resume(returning: ())
      }
    }

    let nilConfiguration = VitalClient.shared.configuration.isNil()
    let nilUserId = VitalClient.shared.userId.isNil()

    XCTAssertTrue(nilUserId)
    XCTAssertTrue(nilConfiguration)

    let securePayload = VitalCoreSecurePayload(
      configuration: .init(),
      apiVersion: apiVersion,
      apiKey: apiKey,
      environment: environment
    )

    let secureStorage = VitalSecureStorage(keychain: .debug)
    try! secureStorage.set(value: userId, key: user_secureStorageKey)
    try! secureStorage.set(value: securePayload, key: core_secureStorageKey)

    let newClient = VitalClient(secureStorage: secureStorage)
    VitalClient.setClient(newClient)

    let _: Void = await withCheckedContinuation { continuation in
      VitalClient.automaticConfiguration {
        continuation.resume(returning: ())
      }
    }

    let nonNilConfiguration = VitalClient.shared.configuration.isNil()
    let nonNilUserId = VitalClient.shared.userId.isNil()

    XCTAssertFalse(nonNilUserId)
    XCTAssertFalse(nonNilConfiguration)
  }

  func testAutoConfigurationDoesNotFailWithUserIdWithoutConfiguration() async {
    let _: Void = await withCheckedContinuation { continuation in
      VitalClient.automaticConfiguration {
        continuation.resume(returning: ())
      }
    }

    XCTAssertNil(VitalClient.shared.configuration.value)
    XCTAssertNil(VitalClient.shared.userId.value)

    // TEST: Set userId only. `automaticConfiguration` should skip setting it,
    // since a configuration is not present.
    let secureStorage = VitalSecureStorage(keychain: .debug)
    try! secureStorage.set(value: userId, key: user_secureStorageKey)

    let newClient = VitalClient(secureStorage: secureStorage)
    VitalClient.setClient(newClient)

    let _: Void = await withCheckedContinuation { continuation in
      VitalClient.automaticConfiguration {
        continuation.resume(returning: ())
      }
    }

    XCTAssertNil(VitalClient.shared.configuration.value)
    XCTAssertNil(VitalClient.shared.userId.value)
  }
  
  func testStorageIsCleanedUpOnUserIdChange() async {
    let storage = VitalCoreStorage(storage: .debug)
    storage.storeConnectedSource(for: userId, with: provider)
    
    client.setConfiguration(
      apiKey: apiKey,
      environment: environment,
      configuration: .init(logsEnable: false),
      storage: storage,
      apiVersion: apiVersion,
      updateAPIClientConfiguration: makeMockApiClient(configuration:)
    )
    
    await VitalClient.setUserId(userId)
    
    await VitalClient.setUserId(UUID())
    
    let isConnected = storage.isConnectedSourceStored(for: userId, with: provider)
    XCTAssertFalse(isConnected)
  }
  
  func testProviderIsStored() async {
    let storage = VitalCoreStorage(storage: .debug)
    storage.storeConnectedSource(for: userId, with: provider)

    client.setConfiguration(
      apiKey: apiKey,
      environment: environment,
      configuration: .init(logsEnable: false),
      storage: storage,
      apiVersion: apiVersion,
      updateAPIClientConfiguration: makeMockApiClient(configuration:)
    )
    
    await VitalClient.setUserId(userId)
    
    let isConnected = try! await VitalClient.shared.isUserConnected(to: provider)
    XCTAssertTrue(isConnected)
  }
}
