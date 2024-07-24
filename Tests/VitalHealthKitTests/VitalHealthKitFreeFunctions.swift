import XCTest
import HealthKit

@testable import VitalHealthKit
@testable import VitalCore

class VitalHealthKitFreeFunctionsTests: XCTestCase {

  func testActivityPatchGroupedByDay() throws {
    typealias FloatingDate = GregorianCalendar.FloatingDate
    let calendar = GregorianCalendar(timeZone: TimeZone(identifier: "Asia/Tokyo")!)

    func makeDaySummary(for date: FloatingDate) -> (FloatingDate, ActivityPatch.DaySummary) {
      (date, ActivityPatch.DaySummary(
        calendarDate: date,
        activeEnergyBurnedSum: 123,
        basalEnergyBurnedSum: 456,
        stepsSum: 234,
        floorsClimbedSum: 567,
        distanceWalkingRunningSum: 789,
        low: 12,
        medium: 34,
        high: 56
      ))
    }

    func makeLocalQuantitySamples(for dates: [FloatingDate]) -> [LocalQuantitySample] {
      dates.enumerated().flatMap { entry in
        [
          LocalQuantitySample(
            value: 100 + Double(entry.offset) * 10,
            // Right on start-of-day
            date: calendar.startOfDay(entry.element),
            unit: "unittest"
          ),
          LocalQuantitySample(
            value: 100 + Double(entry.offset) * 10,
            // Right on ~last instant of the day
            date: calendar.startOfDay(calendar.offset(entry.element, byDays: 1)).addingTimeInterval(-1),
            unit: "unittest"
          ),
          LocalQuantitySample(
            value: 100 + Double(entry.offset) * 10,
            date: calendar.startOfDay(entry.element).addingTimeInterval(60 * (Double(entry.offset) + 1)),
            unit: "unittest"
          ),
          LocalQuantitySample(
            value: 1000 + Double(entry.offset) * 100,
            date: calendar.startOfDay(entry.element).addingTimeInterval(28800 + 60 * (Double(entry.offset) + 1)),
            unit: "unittest"
          ),
        ]
      }
    }

    let sampleDates = [
      FloatingDate(year: 2023, month: 12, day: 1),
      FloatingDate(year: 2023, month: 12, day: 4),
      FloatingDate(year: 2023, month: 12, day: 5),

      // Deliberate rogue entries, expected to be excluded, as grouping is based on day summary,
      // dictionary keys, and no such key exists for these dates.
      FloatingDate(year: 2023, month: 12, day: 7),
      FloatingDate(year: 2023, month: 11, day: 30),

    ]

    let summaries = try XCTUnwrap(
      activityPatchGroupedByDay(
        summaries: Dictionary(uniqueKeysWithValues: [
          makeDaySummary(for: FloatingDate(year: 2023, month: 12, day: 1)),
          // Deliberate 2 day gap (e.g. device is off two days so no data has been collected)
          makeDaySummary(for: FloatingDate(year: 2023, month: 12, day: 4)),
          makeDaySummary(for: FloatingDate(year: 2023, month: 12, day: 5)),

          // Empty summary, expected to be dropped
          (
            FloatingDate(year: 2023, month: 12, day: 6),
            ActivityPatch.DaySummary(calendarDate: FloatingDate(year: 2023, month: 12, day: 4))
          )
        ]),
        samples: ActivityPatch.Activity(
          activeEnergyBurned: makeLocalQuantitySamples(for: sampleDates),
          basalEnergyBurned: makeLocalQuantitySamples(for: sampleDates),
          steps: makeLocalQuantitySamples(for: sampleDates),
          floorsClimbed: makeLocalQuantitySamples(for: sampleDates),
          distanceWalkingRunning: makeLocalQuantitySamples(for: sampleDates),
          vo2Max: makeLocalQuantitySamples(for: sampleDates)
        ),
        in: calendar
      )
    )
    let activities = summaries.activities

    XCTAssertTrue(summaries.isNotEmpty)
    XCTAssertEqual(activities.count, 3)
    XCTAssertEqual(
      activities.compactMap(\.daySummary?.calendarDate),
      [
        FloatingDate(year: 2023, month: 12, day: 1),
        FloatingDate(year: 2023, month: 12, day: 4),
        FloatingDate(year: 2023, month: 12, day: 5),
      ]
    )
    XCTAssert(activities.allSatisfy { $0.activeEnergyBurned.count == 4 })
    XCTAssert(activities.allSatisfy { $0.basalEnergyBurned.count == 4 })
    XCTAssert(activities.allSatisfy { $0.steps.count == 4 })
    XCTAssert(activities.allSatisfy { $0.floorsClimbed.count == 4 })
    XCTAssert(activities.allSatisfy { $0.distanceWalkingRunning.count == 4 })
    XCTAssert(activities.allSatisfy { $0.vo2Max.count == 4 })
  }
}

extension Date {
  func adding(minutes: Int) -> Date {
    return Calendar.current.date(byAdding: .minute, value: minutes, to: self)!
  }
  
  func adding(seconds: Int) -> Date {
    return Calendar.current.date(byAdding: .second, value: seconds, to: self)!
  }
}
