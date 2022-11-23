import XCTest
import HealthKit

@testable import VitalHealthKit
@testable import VitalCore

class VitalHealthKitAnchorTests: XCTestCase {
    
  func testAnchorsPopulation() {
    let type = "type"
    let input: [VitalStatistics] = [
      .init(value: 1, type: type, startDate: Date(), endDate: Date(), sources: []),
      .init(value: 2, type: type, startDate: Date(), endDate: Date(), sources: []),
      .init(value: 3, type: type, startDate: Date(), endDate: Date(), sources: []),
      .init(value: 4, type: type, startDate: Date(), endDate: Date(), sources: []),
      .init(value: 4, type: type, startDate: Date(), endDate: Date(), sources: []),
      .init(value: 0, type: type, startDate: Date(), endDate: Date(), sources: [])
    ]
    
    let values = calculateIdsForAnchorsPopulation(vitalStatistics: input, date: Date())
    XCTAssert(values.count == 4)
    
    let unique = Set(values)
    XCTAssert(unique.count == 4)
  }
  
  func testAnchorsAndData() {
    let type = "type"
    let key = "key"
    let existing: [VitalAnchor] = [
      .init(id: "1"),
      .init(id: "2"),
      .init(id: "3"),
      .init(id: "4"),
      .init(id: "4"),
      .init(id: "0")
    ]
    
    let new: [VitalStatistics] = [
      .init(value: 5, type: type, startDate: Date(), endDate: Date(), sources: []),
      .init(value: 0, type: type, startDate: Date(), endDate: Date(), sources: [])
    ]
    
    let values = calculateIdsForAnchorsAndData(vitalStatistics: new, existingAnchors: existing, key: key, date: Date())
    XCTAssert(values.0.count == 1)
    XCTAssert(values.1.vitalAnchors?.count == 6)
  }
  
  func testAnchorsAndDataNoExisting() {
    let type = "type"
    let key = "key"
    let existing: [VitalAnchor] = [
    ]
    
    let new: [VitalStatistics] = [
      .init(value: 1, type: type, startDate: Date(), endDate: Date(), sources: []),
      .init(value: 2, type: type, startDate: Date(), endDate: Date(), sources: [])
    ]
    
    let values = calculateIdsForAnchorsAndData(vitalStatistics: new, existingAnchors: existing, key: key, date: Date())
    XCTAssert(values.0.count == 2)
    XCTAssert(values.1.vitalAnchors?.count == 2)
  }
}
