import XCTest
import HealthKit

@testable import VitalHealthKit
@testable import VitalCore

class VitalHealthKitClientTests: XCTestCase {
  
  func testSetupWithoutVitalClient() {
    /// This shouldn't crash if called before VitaClient.configure
    VitalHealthKitClient.configure(
      .init(
        backgroundDeliveryEnabled: true, logsEnabled: true
      )
    )
  }

  func testAskingForPermissionsContinuesWithoutAuthentication() async throws {

    await VitalClient.shared.signOut()
    let value = VitalHealthKitClient(store: .debug)

    _ = value.hasAskedForPermission(resource: .body)
    let status = try await value.permissionStatus(for: [.body])
    XCTAssertTrue(status.keys.contains(.body))

    let permission = await value.ask(readPermissions: [.body], writePermissions: [])

    XCTAssertEqual(permission, PermissionOutcome.success)
  }
}
