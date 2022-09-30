import XCTest
import HealthKit

@testable import VitalHealthKit

class VitalHealthKitClientTests: XCTestCase {
  
  func testSetupWithoutVitalClient() async throws {
    /// This shouldn't crash if called before VitaClient.configure
    await VitalHealthKitClient.configure(
      .init(
        backgroundDeliveryEnabled: true, logsEnabled: true
      )
    )
  }
}
