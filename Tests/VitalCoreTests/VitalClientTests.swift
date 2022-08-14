import XCTest

@testable import VitalCore

class VitalClientTests: XCTestCase {
  
  func testInitSetsSharedInstance() throws {
    let client = VitalClient()
    XCTAssertTrue(client === VitalClient.shared)
  }
}

