import XCTest
import HealthKit

@testable import VitalHealthKit
@testable import VitalCore

class VitalHealthKitClientTests: XCTestCase {
  
  func testSetupWithoutVitalClient() {
    /// This shouldn't crash if called before VitaClient.configure
    VitalHealthKitClient.configure(
      .init(
        // 2025-02-26
        // While backgroundDeliveryEnabled: true works in simulator and real devices, it does not
        // work in the XCTest environment due to opaque Swift Concurrency crashes.
        backgroundDeliveryEnabled: false, logsEnabled: true
      )
    )
  }
  
  func testAskingForPermissionsContinuesWithoutAuthentication() async {
    
    await VitalClient.shared.signOut()
    let value = VitalHealthKitClient(store: .debug)
    
    _ = value.hasAskedForPermission(resource: .body)
    let permission = await value.ask(readPermissions: [.body], writePermissions: [])
    
    XCTAssertEqual(permission, PermissionOutcome.success)
  }
}
