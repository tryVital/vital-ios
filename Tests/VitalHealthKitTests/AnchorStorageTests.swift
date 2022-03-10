import XCTest
import HealthKit

@testable import VitalHealthKit

class AnchorStorageTests: XCTestCase {
  
  override func tearDown() {
    AnchorStorage().remove(key: "key")
  }
  
  func testBasicFlow() throws {
    let storage = AnchorStorage()
    let key = "key"
    let anchor = HKQueryAnchor(fromValue: 1)
    
    XCTAssertNil(storage.read(key: key))
    
    storage.set(anchor, forKey: key)
    
    XCTAssertNotNil(storage.read(key: key))
  }
  
  
  func testRecreation() throws {
    let storage = AnchorStorage()
    let key = "key"
    let anchor = HKQueryAnchor(fromValue: 1)
    
    storage.set(anchor, forKey: key)
    
    let newStorage = AnchorStorage()
    _ = newStorage.read(key: key)
    XCTAssertNotNil(storage.read(key: key))
  }
}

