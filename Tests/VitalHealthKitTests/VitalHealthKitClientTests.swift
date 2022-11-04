import XCTest
import HealthKit

@testable import VitalHealthKit
@testable import VitalCore

class VitalHealthKitClientTests: XCTestCase {
  
  func testSetupWithoutVitalClient() async throws {
    /// This shouldn't crash if called before VitaClient.configure
    await VitalHealthKitClient.configure(
      .init(
        backgroundDeliveryEnabled: true, logsEnabled: true
      )
    )
  }
  
  func testAskingForPermissionsContinuesWithoutAuthentication() async {
    
    await VitalClient.shared.cleanUp()
    let value = VitalHealthKitClient(store: .debug)
    
    _ = value.hasAskedForPermission(resource: .body)
    let permission = await value.ask(for: [.body])
    
    XCTAssertEqual(permission, PermissionOutcome.success)
  }
}
