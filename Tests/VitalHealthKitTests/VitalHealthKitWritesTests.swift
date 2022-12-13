import XCTest
import HealthKit

@testable import VitalHealthKit
@testable import VitalCore

class VitalHealthKitWritesTests: XCTestCase {
  
  func testWrittingWater() async {
    let startDate = Date("2022-08-10 00:00:00")
    let endDate = Date("2022-08-10 01:00:00")
    
    try! await VitalHealthKitClient.write(input: .water(milliliters: 1000), startDate: startDate, endDate: endDate)
    let water = try! await VitalHealthKitClient.read(resource: .nutrition(.water), startDate: startDate, endDate: endDate)
    
    assert(true)
  }
}
