import XCTest
@testable import BLEMonitorSimulator

final class SFloatTests: XCTestCase {
  func testSFloatRoundTrips() {
    for value in stride(from: -1000.0, to: 1000.0, by: 0.01) {
      XCTAssertEqual(SFloat.read(data: SFloat.write(value: value)), value, accuracy: 0.5)
    }

    for value in stride(from: -10000.0, to: 10000.0, by: 0.1) {
      XCTAssertEqual(SFloat.read(data: SFloat.write(value: value)), value, accuracy: 5.0)
    }

    let max = SFloat.write(value: SFloat.max)
    XCTAssertEqual(SFloat.read(data: max), SFloat.max)

    let min = SFloat.write(value: SFloat.min)
    XCTAssertEqual(SFloat.read(data: min), SFloat.min)

    XCTAssertEqual(SFloat.read(data: SFloat.write(value: .infinity)), .infinity)
    XCTAssertEqual(SFloat.read(data: SFloat.write(value: -.infinity)), -.infinity)
    XCTAssert(SFloat.read(data: SFloat.write(value: .nan)).isNaN)
  }

  func testSFloatReservedValues() {
    XCTAssertEqual(SFloat.read(data: 0x07FE), .infinity)
    XCTAssert(SFloat.read(data: 0x07FF).isNaN)
    XCTAssert(SFloat.read(data: 0x0800).isNaN)
    XCTAssert(SFloat.read(data: 0x0801).isNaN)
    XCTAssertEqual(SFloat.read(data: 0x0802), -.infinity)
  }
}
