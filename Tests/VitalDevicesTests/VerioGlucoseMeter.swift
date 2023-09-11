import XCTest
@testable import VitalDevices

class VerioGlucoseMeterTest: XCTestCase {
  func test_crc16ccitt() {
    let data = Data([0x05, 0x02, 0x03])

    // CRC: 716D
    XCTAssertEqual(crc16ccitt(data, skipLastTwo: false, skipFirst: false).hexDump(), Data([0x6D, 0x71]).hexDump())
  }
}
