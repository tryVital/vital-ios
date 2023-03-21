import XCTest

@testable import VitalCore

class GregorianCalendarTests: XCTestCase {
  typealias FloatingDate = GregorianCalendar.FloatingDate

  let calendar = GregorianCalendar(timeZone: TimeZone(identifier: "Asia/Tokyo")!)

  func test_floating_date_ordering() {
    XCTAssertFalse(FloatingDate(year: 2023, month: 2, day: 3) < FloatingDate(year: 2023, month: 2, day: 3))
    XCTAssertEqual(FloatingDate(year: 2023, month: 2, day: 3), FloatingDate(year: 2023, month: 2, day: 3))

    // day component
    XCTAssertTrue(FloatingDate(year: 2023, month: 2, day: 3) < FloatingDate(year: 2023, month: 2, day: 4))
    XCTAssertFalse(FloatingDate(year: 2023, month: 2, day: 3) < FloatingDate(year: 2023, month: 2, day: 2))

    // month component
    XCTAssertTrue(FloatingDate(year: 2023, month: 1, day: 3) < FloatingDate(year: 2023, month: 2, day: 3))
    XCTAssertFalse(FloatingDate(year: 2023, month: 3, day: 3) < FloatingDate(year: 2023, month: 2, day: 3))

    // year component
    XCTAssertTrue(FloatingDate(year: 2022, month: 1, day: 3) < FloatingDate(year: 2023, month: 2, day: 3))
    XCTAssertFalse(FloatingDate(year: 2024, month: 2, day: 3) < FloatingDate(year: 2023, month: 2, day: 3))

    // day and month component
    XCTAssertTrue(FloatingDate(year: 2023, month: 2, day: 3) < FloatingDate(year: 2023, month: 5, day: 6))
    XCTAssertFalse(FloatingDate(year: 2023, month: 2, day: 3) < FloatingDate(year: 2023, month: 1, day: 1))

    // month and year component
    XCTAssertTrue(FloatingDate(year: 2023, month: 4, day: 3) < FloatingDate(year: 2025, month: 8, day: 3))
    XCTAssertFalse(FloatingDate(year: 2023, month: 4, day: 3) < FloatingDate(year: 2001, month: 1, day: 3))

    // day, month and year component
    XCTAssertTrue(FloatingDate(year: 2023, month: 4, day: 16) < FloatingDate(year: 2030, month: 7, day: 31))
    XCTAssertFalse(FloatingDate(year: 2023, month: 4, day: 16) < FloatingDate(year: 2003, month: 3, day: 18))
  }

  func test_timeRange_multiple_dates() throws {
    let dateRange = try XCTUnwrap(FloatingDate("2023-01-23")) ... XCTUnwrap(FloatingDate("2023-01-26"))
    let timeRange = calendar.timeRange(of: dateRange)

    // 2023-01-22 15:00:00 UTC
    XCTAssertEqual(timeRange.lowerBound, Date(timeIntervalSince1970: 1674399600))

    // 2023-01-26 15:00:00 UTC
    XCTAssertEqual(timeRange.upperBound, Date(timeIntervalSince1970: 1674745200))
  }

  func test_timeRange_single_date() throws {
    let dateRange = try XCTUnwrap(FloatingDate("2023-01-23")) ... XCTUnwrap(FloatingDate("2023-01-23"))
    let timeRange = calendar.timeRange(of: dateRange)

    // 2023-01-22 15:00:00 UTC
    XCTAssertEqual(timeRange.lowerBound, Date(timeIntervalSince1970: 1674399600))

    // 2023-01-23 15:00:00 UTC
    XCTAssertEqual(timeRange.upperBound, Date(timeIntervalSince1970: 1674486000))
  }

  func test_enumerate_multiple_dates() throws {
    let dateRange = try XCTUnwrap(FloatingDate("2023-01-23")) ... XCTUnwrap(FloatingDate("2023-01-26"))
    let dates = calendar.enumerate(dateRange)

    try XCTAssertEqual(
      dates,
      [
        XCTUnwrap(FloatingDate("2023-01-23")),
        XCTUnwrap(FloatingDate("2023-01-24")),
        XCTUnwrap(FloatingDate("2023-01-25")),
        XCTUnwrap(FloatingDate("2023-01-26"))
      ]
    )
  }

  func test_enumerate_single_date() throws {
    let dateRange = try XCTUnwrap(FloatingDate("2023-01-23")) ... XCTUnwrap(FloatingDate("2023-01-23"))
    let dates = calendar.enumerate(dateRange)

    try XCTAssertEqual(
      dates,
      [
        XCTUnwrap(FloatingDate("2023-01-23")),
      ]
    )
  }
}
