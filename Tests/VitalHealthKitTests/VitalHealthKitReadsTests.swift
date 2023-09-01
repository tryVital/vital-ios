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
    
    let sleeps = stichedSleeps(sleeps: [sleep, sleep1])
    
    XCTAssert(sleeps.count == 1)
    XCTAssert(sleeps[0].startDate == Date("2022-08-06 21:35:31"))
    XCTAssert(sleeps[0].endDate == Date("2022-08-07 05:32:00"))
    
    
    let sleeps1 = stichedSleeps(sleeps: [sleep1, sleep])
    
    XCTAssert(sleeps1.count == 1)
    XCTAssert(sleeps1[0].startDate == Date("2022-08-06 21:35:31"))
    XCTAssert(sleeps1[0].endDate == Date("2022-08-07 05:32:00"))
    
    let sleep2 = SleepPatch.Sleep(
      startDate: Date("2022-08-06 23:45:00"),
      endDate: Date("2022-08-07 05:30:00"),
      sourceBundle: "com.apple.health",
      productType: "product"
    )
    
    let sleeps2 = stichedSleeps(sleeps: [sleep1, sleep2])
    
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
    
    let sleeps = stichedSleeps(sleeps: [sleep, sleep1, sleep2])
    
    XCTAssert(sleeps.count == 1)
    XCTAssert(sleeps[0].startDate == Date("2022-08-07 00:07:00"))
    XCTAssert(sleeps[0].endDate == Date("2022-08-07 07:43:00"))
    
    let sleeps1 = stichedSleeps(sleeps: [sleep2, sleep1, sleep])
    
    XCTAssert(sleeps1.count == 1)
    XCTAssert(sleeps1[0].startDate == Date("2022-08-07 00:07:00"))
    XCTAssert(sleeps1[0].endDate == Date("2022-08-07 07:43:00"))
    
    let sleeps2 = stichedSleeps(sleeps: [sleep1, sleep, sleep2])
    
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
    
    let sleeps = stichedSleeps(sleeps: [sleep, sleep1])

    XCTAssert(sleeps.count == 1)
    XCTAssert(sleeps[0].startDate == Date("2022-08-06 21:35:31"))
    XCTAssert(sleeps[0].endDate == Date("2022-08-07 05:33:00"))
    
    
    let sleeps1 = stichedSleeps(sleeps: [sleep1, sleep])
    
    XCTAssert(sleeps1.count == 1)
    XCTAssert(sleeps1[0].startDate == Date("2022-08-06 21:35:31"))
    XCTAssert(sleeps1[0].endDate == Date("2022-08-07 05:33:00"))
  }
  
  func testStatisticalReadingForLegacyUser() async throws {
    let type = HKQuantityType.quantityType(forIdentifier: .stepCount)!
    let key = "key"
    var vitalStastics: [[VitalStatistics]] = [
      [
        .init(value: 10, type: type, startDate: Date(), endDate: Date()),
        .init(value: 20, type: type, startDate: Date(), endDate: Date()),
        .init(value: 30, type: type, startDate: Date(), endDate: Date())
      ],
      [
        .init(value: 5, type: type, startDate: Date(), endDate: Date())
      ]
    ]
    
    var debug = StatisticsQueryDependencies.debug
    let quantityType = HKQuantityType.quantityType(forIdentifier: .stepCount)!

    let date = Date()
    let (startDate, endDate) = (Date.dateAgo(date, days: 30), date)

    var dateRanges: [Range<Date>] = []
    
    debug.executeStatisticalQuery = { type, queryInterval, granularity in
      XCTAssertEqual(quantityType, type)
      XCTAssertEqual(granularity, .hourly)

      dateRanges.append(queryInterval)
      
      if dateRanges.count == 1 {
        XCTAssert(queryInterval.contains(startDate) == false)
        XCTAssert(queryInterval.contains(endDate) == false)
      }
      
      if dateRanges.count == 2 {
        XCTAssert(queryInterval.contains(startDate) == false)
        XCTAssert(queryInterval.contains(endDate) == false)
      }
      
      let element = vitalStastics.removeFirst()
      return element
    }

    debug.getFirstAndLastSampleTime = { type, _ in
      XCTAssertEqual(quantityType, type)

      return nil
    }
    
    debug.isLegacyType = { type in
      XCTAssertEqual(quantityType, type)
      return true
    }
    debug.isFirstTimeSycingType = { type in
      XCTAssertEqual(quantityType, type)
      return false
    }
    debug.key = { type in
      XCTAssertEqual(quantityType, type)
      return key
    }
    
    debug.vitalAnchorsForType = { type in
      /// It should fail here, since we are dealing with a legacy type
      XCTAssert(false)
      return []
    }
    debug.storedDate = { type in
      XCTAssertEqual(quantityType, type)
      return date.adding(minutes: -10)
    }
    
    do {
      let value = try await queryStatisticsSample(dependency: debug, type: quantityType, startDate: startDate, endDate: endDate)
      
      /// Only one element will be pushed to the server
      XCTAssert(value.statistics.count == 1)
      
      /// We now have 4 ids as part of the anchor
      XCTAssert(value.anchor.vitalAnchors?.count == 4)
      
      XCTAssert(dateRanges.count == 2)
      XCTAssert(dateRanges[0].overlaps(dateRanges[1]) == true)
    }
    catch {
      XCTAssert(false)
    }
  }
  
  func testStatisticalReadingForNewUser() async throws {
    let type = HKQuantityType.quantityType(forIdentifier: .stepCount)!
    let key = "key"
    var vitalStastics: [[VitalStatistics]] = [
      [
        .init(value: 5, type: type, startDate: Date(), endDate: Date())
      ]
    ]
    
    var debug = StatisticsQueryDependencies.debug
    let quantityType = HKQuantityType.quantityType(forIdentifier: .stepCount)!

    let date = Date()
    let (startDate, endDate) = (Date.dateAgo(date, days: 30), date)

    var dateRanges: [Range<Date>] = []

    debug.getFirstAndLastSampleTime = { type, _ in
      XCTAssertEqual(quantityType, type)
      return nil
    }
    
    debug.executeStatisticalQuery = { type, queryInterval, granularity in
      XCTAssertEqual(quantityType, type)
      XCTAssertEqual(granularity, .hourly)

      XCTAssert(queryInterval.contains(startDate) == true)
      XCTAssert(queryInterval.contains(endDate) == false)
      
      dateRanges.append(queryInterval)

      let element = vitalStastics.removeFirst()
      return element
    }
    
    debug.isLegacyType = { type in
      XCTAssertEqual(quantityType, type)
      return false
    }
    debug.isFirstTimeSycingType = { type in
      XCTAssertEqual(quantityType, type)
      return true
    }
    debug.key = { type in
      XCTAssertEqual(quantityType, type)
      return key
    }
    
    debug.vitalAnchorsForType = { type in
      XCTAssertEqual(quantityType, type)
      return [
        .init(id: "1"),
        .init(id: "2")
      ]
    }
    debug.storedDate = { type in
      XCTAssertEqual(quantityType, type)
      return nil
    }

    do {
      let value = try await queryStatisticsSample(dependency: debug, type: quantityType, startDate: startDate, endDate: endDate)
      
      /// Only one element will be pushed to the server
      XCTAssert(value.statistics.count == 1)
      
      /// We now have 3 ids as part of the anchor
      XCTAssert(value.anchor.vitalAnchors?.count == 3)
      XCTAssert(dateRanges.count == 1)
    }
    catch {
      XCTAssert(false)
    }
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
