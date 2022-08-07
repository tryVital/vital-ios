import XCTest
import HealthKit

@testable import VitalHealthKit
@testable import VitalCore

class VitalHealthKitReadsTests: XCTestCase {
    
  func testMergeSleep() {
    let patch: [SleepPatch.Sleep] = []
    XCTAssertEqual(mergeSleeps(sleeps: patch), [])
    
    var sleep = SleepPatch.Sleep(
      startDate: .distantPast,
      endDate: .distantFuture,
      sourceBundle: "com.apple.health",
      productType: "product"
    )
    
    let sleep1 = sleep
    
    XCTAssertEqual(mergeSleeps(sleeps: [sleep]), [sleep])
    XCTAssertEqual(mergeSleeps(sleeps: [sleep, sleep1]), [sleep])
    
    /// Same startDate + endDate
    sleep.startDate = .distantFuture
    
    XCTAssertEqual(mergeSleeps(sleeps: [sleep]), [sleep])
    
    /// Flipped startDate + endDate
    sleep.startDate = .distantFuture
    sleep.endDate = .distantPast

    XCTAssertEqual(mergeSleeps(sleeps: [sleep]), [sleep])
  }
}

