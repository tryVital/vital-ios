import XCTest
import HealthKit

@testable import VitalHealthKit
@testable import VitalCore

class VitalHealthKitFreeFunctionsTests: XCTestCase {
  
  func testAccumulate() {
    let calendar = Calendar.current
    let date = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: Date())!

    let s1: QuantitySample = .init(value: 10, date: date, unit: "")
    let s2: QuantitySample = .init(value: 10, date: date.adding(minutes: 14), unit: "")
    
    let s3: QuantitySample = .init(value: 5, date: date.adding(minutes: 15), unit: "")
    let s4: QuantitySample = .init(value: 5, date: date.adding(minutes: 29), unit: "")
    
    let s5: QuantitySample = .init(value: 1, date: date.adding(minutes: 30), unit: "")
    let s6: QuantitySample = .init(value: 1, date: date.adding(minutes: 44), unit: "")
    
    let s7: QuantitySample = .init(value: 2, date: date.adding(minutes: 45), unit: "")
    let s8: QuantitySample = .init(value: 2, date: date.adding(minutes: 59), unit: "")
    
    let s9: QuantitySample = .init(value: 1, date: date.adding(minutes: 60), unit: "")
  
    func assert(array: [QuantitySample]) {
      XCTAssertTrue(array.count == 5)
      XCTAssertTrue(array[0].value == 20)
      XCTAssertTrue(array[1].value == 10)
      XCTAssertTrue(array[2].value == 2)
      XCTAssertTrue(array[3].value == 4)
      XCTAssertTrue(array[4].value == 1)
    }
    
    let array1 = accumulate([s1, s2, s3, s4, s5, s6, s7, s8, s9], calendar: calendar)
    assert(array: array1)
    
    let array2 = accumulate([s4, s8, s3, s6, s7, s9, s5, s2, s1], calendar: calendar)
    assert(array: array2)
  }
  
  func testAccumulatePerBundle() {
    let calendar = Calendar.current
    let date = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: Date())!
    
    let s1: QuantitySample = .init(value: 10, date: date, sourceBundle: "1", unit: "")
    let s2: QuantitySample = .init(value: 10, date: date.adding(minutes: 14), sourceBundle: "1", unit: "")
    
    let s3: QuantitySample = .init(value: 5, date: date.adding(minutes: 15), sourceBundle: "1", unit: "")
    let s4: QuantitySample = .init(value: 5, date: date.adding(minutes: 29), sourceBundle: "1", unit: "")
    
    let s5: QuantitySample = .init(value: 1, date: date.adding(minutes: 30), sourceBundle: "2", unit: "")
    let s6: QuantitySample = .init(value: 1, date: date.adding(minutes: 44), sourceBundle: "2", unit: "")
    
    let s7: QuantitySample = .init(value: 1, date: date.adding(minutes: 45), sourceBundle: "3", unit: "")
    let s8: QuantitySample = .init(value: 2, date: date.adding(minutes: 50), sourceBundle: "3", unit: "")
    let s9: QuantitySample = .init(value: 3, date: date.adding(minutes: 59), sourceBundle: "3", unit: "")
    
    
    func assert(array: [QuantitySample]) {
      XCTAssertTrue(array.count == 4)
      XCTAssertTrue(array[0].value == 20)
      XCTAssertTrue(array[1].value == 10)
      XCTAssertTrue(array[2].value == 2)
      XCTAssertTrue(array[3].value == 6)
    }
    
    let array1 = accumulate([s1, s2, s3, s4, s5, s6, s7, s8, s9], calendar: calendar)
    assert(array: array1)
    
    let array2 = accumulate([s4, s8, s3, s6, s7, s9, s5, s2, s1], calendar: calendar)
    assert(array: array2)
  }
  
  func testAverageTwoElements() {
    let calendar = Calendar.current
    let date = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: Date())!
    
    let s1: QuantitySample = .init(value: 12, date: date, unit: "")
    let s2: QuantitySample = .init(value: 10, date: date.adding(seconds: 1), unit: "")
    
    let array = average([s1, s2], calendar: calendar)
    
    XCTAssertTrue(array.count == 2)
    XCTAssertTrue(array[0].value == 12)
    XCTAssertTrue(array[1].value == 10)
  }
  
  func testAverage() {
    let calendar = Calendar.current
    let date = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: Date())!
    
    let s1: QuantitySample = .init(value: 12, date: date, unit: "")
    let s2: QuantitySample = .init(value: 1, date: date.adding(seconds: 1), unit: "")
    let s3: QuantitySample = .init(value: 15, date: date.adding(seconds: 3), unit: "")
    let s4: QuantitySample = .init(value: 11, date: date.adding(seconds: 4), unit: "")

    let s5: QuantitySample = .init(value: 10, date: date.adding(seconds: 6), unit: "")
    let s6: QuantitySample = .init(value: 11, date: date.adding(seconds: 7), unit: "")
    let s7: QuantitySample = .init(value: 12, date: date.adding(seconds: 8), unit: "")
    let s8: QuantitySample = .init(value: 13, date: date.adding(seconds: 9), unit: "")
        
    func assert(array: [QuantitySample]) {
      XCTAssertTrue(array.count == 4)
      XCTAssertTrue(array[0].value == 9.75)
      XCTAssertTrue(array[1].value == 1)
      XCTAssertTrue(array[2].value == 15)
      XCTAssertTrue(array[3].value == 11.5)
    }
    
    let array1 = average([s1, s2, s3, s4, s5, s6, s7, s8], calendar: calendar)
    assert(array: array1)
    
    let array2 = average([s3, s7, s1, s4, s8, s6, s2, s5], calendar: calendar)
    assert(array: array2)
  }
  
  func testAveragePerBundle() {
    let calendar = Calendar.current
    let date = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: Date())!
    
    let s1: QuantitySample = .init(value: 12, date: date, sourceBundle: "1", unit: "")
    let s2: QuantitySample = .init(value: 1, date: date.adding(seconds: 1), sourceBundle: "1", unit: "")
    let s3: QuantitySample = .init(value: 15, date: date.adding(seconds: 3), sourceBundle: "1", unit: "")
    let s4: QuantitySample = .init(value: 11, date: date.adding(seconds: 4), sourceBundle: "1", unit: "")
    
    let s5: QuantitySample = .init(value: 9, date: date.adding(seconds: 6), sourceBundle: "2", unit: "")
    let s6: QuantitySample = .init(value: 11, date: date.adding(seconds: 7), sourceBundle: "2", unit: "")
    let s7: QuantitySample = .init(value: 7, date: date.adding(seconds: 8), sourceBundle: "2", unit: "")
    
    let s8: QuantitySample = .init(value: 13, date: date.adding(seconds: 9), sourceBundle: "3", unit: "")
    
    func assert(array: [QuantitySample]) {
      XCTAssertTrue(array.count == 7)
      XCTAssertTrue(array[0].value == 9.75)
      XCTAssertTrue(array[1].value == 1)
      XCTAssertTrue(array[2].value == 15)
      XCTAssertTrue(array[3].value == 9)
      XCTAssertTrue(array[4].value == 11)
      XCTAssertTrue(array[5].value == 7)
      XCTAssertTrue(array[6].value == 13)
    }
    
    let array1 = average([s1, s2, s3, s4, s5, s6, s7, s8], calendar: calendar)
    assert(array: array1)
    
    let array2 = average([s3, s7, s1, s4, s8, s6, s2, s5], calendar: calendar)
    assert(array: array2)
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
