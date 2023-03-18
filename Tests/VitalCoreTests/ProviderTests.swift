import XCTest
import Mocker

@testable import VitalCore

class ProviderTests: XCTestCase {
  func test_provider_slug_encoding() throws {
    let encoder = JSONEncoder()
    let slug = Provider.Slug.appleHealthKit
    let data = try encoder.encode(slug)

    XCTAssertEqual(data, "\"\(slug.rawValue)\"".data(using: .utf8))
  }

  func test_provider_slug_decoding() throws {
    let decoder = JSONDecoder()
    let slug = Provider.Slug.appleHealthKit
    let data = try XCTUnwrap("\"\(slug.rawValue)\"".data(using: .utf8))

    XCTAssertEqual(slug, try decoder.decode(Provider.Slug.self, from: data))
  }

  func test_provider_slug_encoding_unknown_value() throws {
    let encoder = JSONEncoder()
    let slug = Provider.Slug.unknown("whomst")
    let data = try encoder.encode(slug)

    XCTAssertEqual(data, "\"\(slug.rawValue)\"".data(using: .utf8))
  }

  func test_provider_slug_decoding_unknown_value() throws {
    let decoder = JSONDecoder()
    let slug = Provider.Slug.unknown("whomst")
    let data = try XCTUnwrap("\"\(slug.rawValue)\"".data(using: .utf8))

    XCTAssertEqual(slug, try decoder.decode(Provider.Slug.self, from: data))
  }
}
