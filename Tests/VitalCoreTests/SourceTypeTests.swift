import XCTest
@testable import VitalCore

class SourceTypeTests: XCTestCase {
  func test_sourceTypeRoundtripping() throws {
    let sourceTypes = [
      SourceType.app,
      SourceType.automatic,
      SourceType.chestStrap,
      SourceType.cuff,
      SourceType.fingerprick,
      SourceType.manualScan,
      SourceType.multipleSources,
      SourceType.phone,
      SourceType.ring,
      SourceType.unknown,
      SourceType.unrecognized("unittest1"),
      SourceType.unrecognized("unittest2"),
    ]

    let encoder = JSONEncoder()
    let decoder = JSONDecoder()

    for sourceType in sourceTypes {
      XCTAssertEqual(sourceType, SourceType(rawValue: sourceType.rawValue))

      let encoded = try encoder.encode(sourceType)
      let decoded = try decoder.decode(SourceType.self, from: encoded)
      XCTAssertEqual(sourceType, decoded)
    }
  }

  func test_unrecognizedEqualsToNamed() {
    XCTAssertEqual(SourceType.app, SourceType.unrecognized("app"))
    XCTAssertEqual(SourceType.app.hashValue, SourceType.unrecognized("app").hashValue)
  }
}
