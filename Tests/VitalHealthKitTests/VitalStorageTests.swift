import XCTest
import HealthKit

@testable import VitalHealthKit

class VitalStorageTests: XCTestCase {
  
  override func tearDown() {
    VitalStorage().remove(key: "key")
  }
  
  func testAnchorStorage() throws {
    let storage = VitalStorage()
    let key = "key"
    let anchor = HKQueryAnchor(fromValue: 1)
    
    XCTAssertNil(storage.read(key: key))
    
    storage.store(entity: .anchor(key, anchor))
    
    let storedAnchor = storage.read(key: key)?.anchor
    XCTAssertNotNil(storedAnchor)
  }
  
  
  func testStorageRecreation() throws {
    let storage = VitalStorage()
    let key = "key"
    let anchor = HKQueryAnchor(fromValue: 1)
    
    storage.store(entity: .anchor(key, anchor))

    let newStorage = VitalStorage()
    _ = newStorage.read(key: key)
    
    let storedAnchor = storage.read(key: key)?.anchor

    XCTAssertNotNil(storedAnchor)
  }
  
  func testDateStorage() throws {
    let storage = VitalStorage()
    let key = "key"
    let date = Date()
    
    storage.store(entity: .date(key, date))
    
    let newStorage = VitalStorage()
    _ = newStorage.read(key: key)
    
    let storedDate = storage.read(key: key)?.date
    
    XCTAssertNotNil(storedDate)
    XCTAssertEqual(storedDate!.timeIntervalSinceReferenceDate, date.timeIntervalSinceReferenceDate, accuracy: 0.01)
  }
  
  func testNilDateStorage() throws {
    let storage = VitalStorage()
    let key = "key"
    
    let storedDate = storage.read(key: key)
    XCTAssertNil(storedDate)
  }
}

