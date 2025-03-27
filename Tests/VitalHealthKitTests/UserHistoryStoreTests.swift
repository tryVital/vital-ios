@_spi(VitalSDKInternals) @testable import VitalCore
@testable import VitalHealthKit
import XCTest
import Foundation

let calendar = GregorianCalendar.utc
let today = calendar.floatingDate(of: Date(timeIntervalSince1970: 1743011768))

@available(iOS 16.0, *)
class UserHistoryStoreTests: XCTestCase {
  var directoryUrl: URL!
  var store: UserHistoryStore!

  override func setUpWithError() throws {
    UserHistoryStore.getCurrentTimeZone = { TimeZone(identifier: "Asia/Tokyo")! }

    directoryUrl = URL.temporaryDirectory.appending(component: "user-history-store-" + UUID().uuidString, directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: directoryUrl, withIntermediateDirectories: true)
    store = UserHistoryStore(storage: VitalGistStorage(directoryURL: directoryUrl))
  }

  override func tearDownWithError() throws {
    UserHistoryStore.getCurrentTimeZone = { TimeZone.current }
    try FileManager.default.removeItem(at: directoryUrl)
  }

  func testLastObservationWins() {
    store.record(TimeZone(identifier: "Europe/Berlin")!, date: today)
    store.record(TimeZone(identifier: "Europe/London")!, date: today)

    UserHistoryStore.getCurrentTimeZone = { TimeZone(identifier: "Asia/Tokyo")! }

    let resolvedTimeZone = store.resolver().timeZone(for: today)
    // Last observation wins
    XCTAssertEqual(resolvedTimeZone, TimeZone(identifier: "Europe/London")!)
  }

  func testCanHaveMultipleObservationsForDifferentDays() {
    let yesterday = calendar.offset(today, byDays: -1)
    let weekAgo = calendar.offset(today, byDays: -7)
    let twoWeeksAgo = calendar.offset(today, byDays: -14)

    store.record(TimeZone(identifier: "America/New_York")!, date: weekAgo)
    store.record(TimeZone(identifier: "Europe/Berlin")!, date: today)
    store.record(TimeZone(identifier: "Europe/London")!, date: yesterday)

    UserHistoryStore.getCurrentTimeZone = { TimeZone(identifier: "Asia/Tokyo")! }

    let resolver = store.resolver()

    XCTAssertEqual(resolver.timeZone(for: weekAgo), TimeZone(identifier: "America/New_York")!)
    XCTAssertEqual(resolver.timeZone(for: today), TimeZone(identifier: "Europe/Berlin")!)
    XCTAssertEqual(resolver.timeZone(for: yesterday), TimeZone(identifier: "Europe/London")!)

    // No record; should use current timezone
    XCTAssertEqual(resolver.timeZone(for: twoWeeksAgo), TimeZone(identifier: "Asia/Tokyo")!)
  }

  func testReturnCurrentTimeZone() {
    let resolvedTimeZone = store.resolver().timeZone(for: today)
    // No recorded observation; return current timezone
    XCTAssertEqual(resolvedTimeZone, TimeZone(identifier: "Asia/Tokyo")!)
  }

  func testShouldPurgeExcessRecords() {
    let start = calendar.offset(today, byDays: -89)

    for date in calendar.enumerate(start ... today) {
      store.record(TimeZone(identifier: "Europe/London")!, date: date)
    }

    let resolver = store.resolver()
    let resolved = calendar.enumerate(start ... today).map { date in resolver.timeZone(for: date) }

    // No recorded observation; return current timezone
    XCTAssertEqual(
      resolved,
      Array(repeating: TimeZone(identifier: "Asia/Tokyo")!, count: 90 - UserHistoryStore.keepMostRecent)
      + Array(repeating: TimeZone(identifier: "Europe/London")!, count: UserHistoryStore.keepMostRecent)
    )
  }
}

