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
    storage.store(entity: .init(key: key, anchor: anchor, date: Date(), vitalAnchors: nil))
        
    let storedAnchor = storage.read(key: key)?.anchor
    XCTAssertNotNil(storedAnchor)
    XCTAssert(storage.isLegacyType(for: key) == true)
  }
  
  func testStorageRecreation() throws {
    let storage = VitalHealthKitStorage(storage: .debug)
    let key = "key"
    let anchor = HKQueryAnchor(fromValue: 1)
    
    storage.store(entity: .init(key: key, anchor: anchor, date: Date(), vitalAnchors: nil))

    let newStorage = VitalHealthKitStorage(storage: .debug)
    _ = newStorage.read(key: key)
    
    let storedAnchor = storage.read(key: key)?.anchor

    XCTAssertNotNil(storedAnchor)
    XCTAssert(storage.isLegacyType(for: key) == true)
  }
    
  func testNilDateStorage() throws {
    let storage = VitalHealthKitStorage(storage: .debug)
    let key = "key"
    
    let storedDate = storage.read(key: key)
    XCTAssertNil(storedDate)
    XCTAssert(storage.isFirstTimeSycingType(for: key) == true)
  }
  
  func testLegacy() throws {
    let storage = VitalHealthKitStorage(storage: .debug)
    let key = "key"
    
    storage.store(entity: .init(key: key, anchor: nil, date: Date(), vitalAnchors: nil))
    XCTAssert(storage.isLegacyType(for: key) == true)
    
    storage.remove(key: key)
    storage.store(entity: .init(key: key, anchor: nil, date: nil, vitalAnchors: []))
    XCTAssert(storage.isLegacyType(for: key) == false)
  }
}

