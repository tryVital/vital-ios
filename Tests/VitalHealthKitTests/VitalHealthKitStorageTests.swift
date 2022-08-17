import XCTest
import HealthKit

@testable import VitalHealthKit
@testable import VitalCore

class VitalHealthKitStorageTests: XCTestCase {
  
  override func tearDown() {
    VitalHealthKitStorage(storage: .debug).remove(key: "key")
  }
  
  func testAnchorStorage() throws {
    let storage = VitalHealthKitStorage(storage: .debug)
    let key = "key"
    let anchor = HKQueryAnchor(fromValue: 1)
    
    XCTAssertNil(storage.read(key: key))
    storage.store(entity: .init(key: key, anchor: anchor))
        
    let storedAnchor = storage.read(key: key)?.anchor
    XCTAssertNotNil(storedAnchor)
  }
  
  func testStorageRecreation() throws {
    let storage = VitalHealthKitStorage(storage: .debug)
    let key = "key"
    let anchor = HKQueryAnchor(fromValue: 1)
    
    storage.store(entity: .init(key: key, anchor: anchor))

    let newStorage = VitalHealthKitStorage(storage: .debug)
    _ = newStorage.read(key: key)
    
    let storedAnchor = storage.read(key: key)?.anchor

    XCTAssertNotNil(storedAnchor)
  }
    
  func testNilDateStorage() throws {
    let storage = VitalHealthKitStorage(storage: .debug)
    let key = "key"
    
    let storedDate = storage.read(key: key)
    XCTAssertNil(storedDate)
  }
}

