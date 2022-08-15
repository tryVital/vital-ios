import XCTest
import Mocker

@testable import VitalCore

let environment = Environment.sandbox(.us)
let userId = UUID()
let apiKey = UUID().uuidString
let apiVersion = "2.0"

class VitalClientTests: XCTestCase {
  
  func testInitSetsSharedInstance() throws {
    let client = VitalClient()
    XCTAssertTrue(client === VitalClient.shared)
  }
  
  func testStorageAndCleanUp() async throws {
    let environment = Environment.sandbox(.us)
    let mockedApiClient = makeMockApiClient(environment: environment, apiKey: apiKey)
    
    let storage = VitalCoreStorage(storage: .debug)
    storage.storeConnectedSource(for: userId, with: .strava)
    
    let configuration = VitalCoreConfiguration(
      apiVersion: apiVersion,
      apiClient: mockedApiClient,
      environment: environment,
      storage: storage
    )
    
    let secureStorage = VitalSecureStorage(keychain: .debug)
    
    let client = VitalClient(
      secureStorage: secureStorage,
      configuration: .init(value: configuration),
      userId: .init(value: .init())
    )
    
    VitalClient.setUserId(userId)
    
    await client.setConfiguration(
      apiKey: apiKey,
      environment: environment,
      configuration: .init(logsEnable: false),
      storage: storage,
      apiClient: mockedApiClient,
      logger: nil,
      apiVersion: apiVersion
    )

    let securePayload: VitalCoreSecurePayload? = try? secureStorage.get(key: core_secureStorageKey)
    let storedUserId: UUID? = try? secureStorage.get(key: user_secureStorageKey)
    
    XCTAssertEqual(securePayload?.configuration.logsEnable, false)
    XCTAssertEqual(securePayload?.apiVersion, apiVersion)
    XCTAssertEqual(securePayload?.apiKey, apiKey)
    XCTAssertEqual(securePayload?.environment, environment)

    XCTAssertEqual(storedUserId, userId)
    XCTAssertTrue(
      storage.isConnectedSourceStored(for: userId, with: .strava)
    )
    
    await VitalClient.shared.cleanUp()
    
    let inMemoryStoredUser = await VitalClient.shared.userId.isNil()
    let inMemoryStoredConfiguration = await VitalClient.shared.configuration.isNil()
    
    XCTAssertTrue(inMemoryStoredUser)
    XCTAssertTrue(inMemoryStoredConfiguration)

    let nilSecurePayload: VitalCoreSecurePayload? = try? secureStorage.get(key: core_secureStorageKey)
    let nilStoredUserId: UUID? = try? secureStorage.get(key: user_secureStorageKey)

    XCTAssertNil(nilSecurePayload)
    XCTAssertNil(nilStoredUserId)
    
    XCTAssertFalse(
      storage.isConnectedSourceStored(for: userId, with: .strava)
    )  }
}
