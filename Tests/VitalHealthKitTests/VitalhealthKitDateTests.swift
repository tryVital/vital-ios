import XCTest
import HealthKit

@testable import VitalHealthKit
@testable import VitalCore

class VitalhealthKitDateTests: XCTestCase {
  
  func assertComponents(date: Date, hour: Int, minute: Int, second: Int) {
    let hourValue = vitalCalendar.component(.hour, from: date)
    let minuteValue = vitalCalendar.component(.minute, from: date)
    let secondValue = vitalCalendar.component(.second, from: date)
    
    XCTAssert(hourValue == hour)
    XCTAssert(minuteValue == minute)
    XCTAssert(secondValue == second)
  }
  
  func testDateRounding() {
    let now = Date()
    let calendar = vitalCalendar
    let date = calendar.date(bySettingHour: 11, minute: 12, second: 13, of: now)!
    

    let round = date.nextHour
    assertComponents(date: round, hour: 12, minute: 0, second: 0)
    
    let anotherRound = round.nextHour
    assertComponents(date: anotherRound, hour: 12, minute: 0, second: 0)
  }
  
  func testDateRoundingAtEdge() {
    let now = Date()
    let date = vitalCalendar.date(bySettingHour: 23, minute: 12, second: 13, of: now)!
    let currentDay = vitalCalendar.component(.day, from: date)

    let round = date.nextHour
    let nextDay = vitalCalendar.component(.day, from: round)
    
    assertComponents(date: round, hour: 00, minute: 0, second: 0)
    XCTAssert(currentDay != nextDay)
  }
}

