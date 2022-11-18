import XCTest
import HealthKit

@testable import VitalHealthKit
@testable import VitalCore





class VitalHealthKitAnchorTests: XCTestCase {
    
  func testGenerateIdIsReferentialTransparent() {
    let now = Date()
    let yesterday = Calendar.autoupdatingCurrent.date(byAdding: .day, value: -1, to: now)!
    
    let id = generateId(for: now, endDate: yesterday, value: 20, type: "foo_bar")
    let id2 = generateId(for: now, endDate: yesterday, value: 20, type: "foo_bar")
    
    XCTAssert(id == id2)
  }
  
  
  func testBasic() {
    let date = Date()
    
    let existingAnchors: [Anchor] = [
      .init(id: "1", stamp: date),
      .init(id: "3", stamp: date)
      ]
    
    let newAnchors: [Anchor] = [
      .init(id: "1", stamp: date),
      .init(id: "2", stamp: date)
    ]
    
    let dataToPush = dataToPush(old: existingAnchors, new: newAnchors)
    
    XCTAssert(dataToPush == [.init(id: "2", stamp: date)])
  }
}
