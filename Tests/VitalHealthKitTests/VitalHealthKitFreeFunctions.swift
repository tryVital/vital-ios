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

  
  func testAccumulateRealisticExample() {
    let calendar = Calendar.current

    func makeSample(hour: Int, minute: Int, value: Double) -> QuantitySample {
      let date = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: Date())!
      return .init(value: value, date: date, sourceBundle: "1", unit: "")
    }
    
    let array = [
    makeSample(hour: 7, minute: 3, value: 1),
    makeSample(hour: 7, minute: 25, value: 57),
    makeSample(hour: 7, minute: 27, value: 48),
    makeSample(hour: 7, minute: 35, value: 19),
    makeSample(hour: 8, minute: 5, value: 189),
    makeSample(hour: 8, minute: 14, value: 254),
    makeSample(hour: 8, minute: 18, value: 126),
    makeSample(hour: 8, minute: 28, value: 124),
    makeSample(hour: 9, minute: 22, value: 11),
    
    makeSample(hour: 9, minute: 44, value: 56),
    makeSample(hour: 10, minute: 33, value: 66),
    makeSample(hour: 13, minute: 35, value: 67),
    makeSample(hour: 14, minute: 09, value: 32),
    makeSample(hour: 14, minute: 10, value: 23),
    makeSample(hour: 14, minute: 17, value: 19),
    makeSample(hour: 14, minute: 19, value: 39),
    makeSample(hour: 14, minute: 43, value: 8),
    makeSample(hour: 15, minute: 02, value: 55),
    
    makeSample(hour: 15, minute: 28, value: 5),
    makeSample(hour: 16, minute: 19, value: 168),
    makeSample(hour: 16, minute: 31, value: 320),
    makeSample(hour: 16, minute: 39, value: 90),
    makeSample(hour: 16, minute: 46, value: 325),
    makeSample(hour: 16, minute: 46, value: 68),
    makeSample(hour: 16, minute: 49, value: 132),
    makeSample(hour: 16, minute: 59, value: 130),
    makeSample(hour: 17, minute: 07, value: 201),
    
    makeSample(hour: 17, minute: 48, value: 114),
    makeSample(hour: 17, minute: 52, value: 114),
    makeSample(hour: 18, minute: 7, value: 101),
    makeSample(hour: 18, minute: 17, value: 245),
    makeSample(hour: 18, minute: 26, value: 244),
    makeSample(hour: 18, minute: 31, value: 70),
    makeSample(hour: 18, minute: 51, value: 120),
    makeSample(hour: 19, minute: 05, value: 8),
    makeSample(hour: 19, minute: 34, value: 141),
    makeSample(hour: 20, minute: 50, value: 68),
    makeSample(hour: 21, minute: 08, value: 35),
    ]
    
    let array1 = accumulate(array, calendar: calendar)
    let array2 = accumulate(array1, calendar: calendar)

    XCTAssert(array1 == array2)
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
