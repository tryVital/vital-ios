import XCTest
import HealthKit

@testable import VitalHealthKit
@testable import VitalCore

class VitalHealthKitReadsTests: XCTestCase {
  
  func testMerge_nonConsecutiveSleep() {
    let sleep = SleepPatch.Sleep(
      startDate: Date("2022-08-07 00:27:00"),
      endDate: Date("2022-08-07 00:36:00"),
      sourceBundle: "com.apple.health",
      productType: "product"
    )
    
    let sleep1 = SleepPatch.Sleep(
      startDate: Date("2022-08-08 00:44:00"),
      endDate: Date("2022-08-08 07:43:00"),
      sourceBundle: "com.apple.health",
      productType: "product"
    )
    
    let sleep2 = SleepPatch.Sleep(
      startDate: Date("2022-08-07 00:07:00"),
      endDate: Date("2022-08-07 06:40:00"),
      sourceBundle: "com.apple.health",
      productType: "product"
    )
    
    let sleep3 = SleepPatch.Sleep(
      startDate: Date("2022-08-10 00:44:00"),
      endDate: Date("2022-08-10 07:43:00"),
      sourceBundle: "com.apple.health",
      productType: "product"
    )
    
    let sleep4 = SleepPatch.Sleep(
      startDate: Date("2022-08-07 00:55:00"),
      endDate: Date("2022-08-07 06:43:00"),
      sourceBundle: "com.apple.health",
      productType: "product"
    )
    
    XCTAssertEqual(mergeSleeps(sleeps: [sleep, sleep1, sleep2, sleep3, sleep4]).count, 3)
  }

  func testMerge_overlappingSleeps() {
    let sleep = SleepPatch.Sleep(
      startDate: Date("2023-01-26 05:01:16"),
      endDate: Date("2023-01-26 12:21:16"),
      sourceBundle: "com.apple.health",
      productType: "product"
    )

    let sleep1 = SleepPatch.Sleep(
      startDate: Date("2023-01-26 04:54:16"),
      endDate: Date("2023-01-26 12:21:16"),
      sourceBundle: "com.apple.health",
      productType: "product"
    )

    XCTAssertEqual(mergeSleeps(sleeps: [sleep, sleep1]).count, 1)
    XCTAssertEqual(mergeSleeps(sleeps: [sleep1, sleep]).count, 1)

  }

  
  func testStichSleep_overlap() {

    let sleep = SleepPatch.Sleep(
      startDate: Date("2022-08-06 21:35:31"),
      endDate: Date("2022-08-07 05:30:00"),
      sourceBundle: "com.apple.health",
      productType: "product"
    )
    
    let sleep1 = SleepPatch.Sleep(
      startDate: Date("2022-08-07 05:28:00"),
      endDate: Date("2022-08-07 05:32:00"),
      sourceBundle: "com.apple.health",
      productType: "product"
    )
    
    let sleeps = stitchedSleeps(sleeps: [sleep, sleep1], sourceType: .watch)
    
    XCTAssert(sleeps.count == 1)
    XCTAssert(sleeps[0].startDate == Date("2022-08-06 21:35:31"))
    XCTAssert(sleeps[0].endDate == Date("2022-08-07 05:32:00"))
    
    
    let sleeps1 = stitchedSleeps(sleeps: [sleep1, sleep], sourceType: .watch)
    
    XCTAssert(sleeps1.count == 1)
    XCTAssert(sleeps1[0].startDate == Date("2022-08-06 21:35:31"))
    XCTAssert(sleeps1[0].endDate == Date("2022-08-07 05:32:00"))
    
    let sleep2 = SleepPatch.Sleep(
      startDate: Date("2022-08-06 23:45:00"),
      endDate: Date("2022-08-07 05:30:00"),
      sourceBundle: "com.apple.health",
      productType: "product"
    )
    
    let sleeps2 = stitchedSleeps(sleeps: [sleep1, sleep2], sourceType: .watch)
    
    XCTAssert(sleeps2.count == 1)
    XCTAssert(sleeps2[0].startDate == Date("2022-08-06 23:45:00"))
    XCTAssert(sleeps2[0].endDate == Date("2022-08-07 05:32:00"))
  }
  
  func testStichSleep_real_overlap() {
    let sleep = SleepPatch.Sleep(
      startDate: Date("2022-08-07 00:27:00"),
      endDate: Date("2022-08-07 00:36:00"),
      sourceBundle: "com.apple.health",
      productType: "product"
    )
    
    let sleep1 = SleepPatch.Sleep(
      startDate: Date("2022-08-07 00:44:00"),
      endDate: Date("2022-08-07 07:43:00"),
      sourceBundle: "com.apple.health",
      productType: "product"
    )
    
    let sleep2 = SleepPatch.Sleep(
      startDate: Date("2022-08-07 00:07:00"),
      endDate: Date("2022-08-07 06:40:00"),
      sourceBundle: "com.apple.health",
      productType: "product"
    )
    
    let sleeps = stitchedSleeps(sleeps: [sleep, sleep1, sleep2], sourceType: .watch)
    
    XCTAssert(sleeps.count == 1)
    XCTAssert(sleeps[0].startDate == Date("2022-08-07 00:07:00"))
    XCTAssert(sleeps[0].endDate == Date("2022-08-07 07:43:00"))
    
    let sleeps1 = stitchedSleeps(sleeps: [sleep2, sleep1, sleep], sourceType: .watch)
    
    XCTAssert(sleeps1.count == 1)
    XCTAssert(sleeps1[0].startDate == Date("2022-08-07 00:07:00"))
    XCTAssert(sleeps1[0].endDate == Date("2022-08-07 07:43:00"))
    
    let sleeps2 = stitchedSleeps(sleeps: [sleep1, sleep, sleep2], sourceType: .watch)
    
    XCTAssert(sleeps2.count == 1)
    XCTAssert(sleeps2[0].startDate == Date("2022-08-07 00:07:00"))
    XCTAssert(sleeps2[0].endDate == Date("2022-08-07 07:43:00"))
  }
  
  func testStichSleep_no_overlap() {
    
    let sleep = SleepPatch.Sleep(
      startDate: Date("2022-08-06 21:35:31"),
      endDate: Date("2022-08-07 05:30:00"),
      sourceBundle: "com.apple.health",
      productType: "product"
    )
    
    let sleep1 = SleepPatch.Sleep(
      startDate: Date("2022-08-07 05:31:00"),
      endDate: Date("2022-08-07 05:33:00"),
      sourceBundle: "com.apple.health",
      productType: "product"
    )
    
    let sleeps = stitchedSleeps(sleeps: [sleep, sleep1], sourceType: .watch)

    XCTAssert(sleeps.count == 1)
    XCTAssert(sleeps[0].startDate == Date("2022-08-06 21:35:31"))
    XCTAssert(sleeps[0].endDate == Date("2022-08-07 05:33:00"))
    
    
    let sleeps1 = stitchedSleeps(sleeps: [sleep1, sleep], sourceType: .watch)
    
    XCTAssert(sleeps1.count == 1)
    XCTAssert(sleeps1[0].startDate == Date("2022-08-06 21:35:31"))
    XCTAssert(sleeps1[0].endDate == Date("2022-08-07 05:33:00"))
  }

  func testStichSleep_no_overlap_iphoneSamplesWithLongGaps() {

    let sleep = SleepPatch.Sleep(
      startDate: Date("2022-08-06 21:35:31"),
      endDate: Date("2022-08-07 05:30:00"),
      sourceBundle: "com.apple.health",
      productType: "product"
    )

    // Awake for 91 minutes, and then nap for 24 minutes

    let sleep1 = SleepPatch.Sleep(
      startDate: Date("2022-08-07 07:01:00"),
      endDate: Date("2022-08-07 07:25:00"),
      sourceBundle: "com.apple.health",
      productType: "product"
    )

    let sleeps = stitchedSleeps(sleeps: [sleep, sleep1], sourceType: .phone)

    XCTAssert(sleeps.count == 1)
    XCTAssert(sleeps[0].startDate == Date("2022-08-06 21:35:31"))
    XCTAssert(sleeps[0].endDate == Date("2022-08-07 07:25:00"))


    let sleeps1 = stitchedSleeps(sleeps: [sleep1, sleep], sourceType: .phone)

    XCTAssert(sleeps1.count == 1)
    XCTAssert(sleeps1[0].startDate == Date("2022-08-06 21:35:31"))
    XCTAssert(sleeps1[0].endDate == Date("2022-08-07 07:25:00"))
  }
}

extension Date {
  init(_ dateString:String) {
    let dateStringFormatter = DateFormatter()
    dateStringFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
    dateStringFormatter.locale = NSLocale(localeIdentifier: "en_US_POSIX") as Locale
    let date = dateStringFormatter.date(from: dateString)!
    self.init(timeInterval:0, since:date)
  }
}
