import SwiftUI
import HealthKit
import VitalCore

class VitalHealthKitStorage {
  
  private let prefix = "vital_anchor_"
  private let flag = "vital_anchor_"

  private let userDefaults: UserDefaults
  
  init(userDefaults: UserDefaults = .init(suiteName: "tryVital")!) {
    self.userDefaults = userDefaults
        
    let defaultValue: [String: String] = [:]
    userDefaults.register(defaults: defaultValue)
  }
  
  func storeFlag(for resource: VitalResource) {
    userDefaults.set(true, forKey: String(describing: resource))
  }
  
  func readFlag(for resource: VitalResource) -> Bool {
    return userDefaults.bool(forKey: String(describing: resource))
  }
  
  func store(entity: StoredAnchor) {
    let prefixedKey = prefix + entity.key
    
    guard let data = try? NSKeyedArchiver.archivedData(withRootObject: entity.anchor, requiringSecureCoding: true) else {
      return
    }
    
    let encoded = data.base64EncodedString()
    userDefaults.set(encoded, forKey: prefixedKey)
  }
  
  func read(key: String) -> StoredAnchor? {
    let prefixedKey = prefix + key
    
    if let storedString = userDefaults.string(forKey: prefixedKey),
       let data = Data(base64Encoded: storedString) {
      
      let anchor = try? NSKeyedUnarchiver.unarchivedObject(ofClass: HKQueryAnchor.self, from: data)
      return StoredAnchor(key: key, anchor: anchor)
    }
    
    return nil
  }

  func remove(key: String) {
    userDefaults.removeObject(forKey: prefix + key)
  }
}

struct StoredAnchor {
  let key: String
  let anchor: HKQueryAnchor
  
  init?(key: String, anchor: HKQueryAnchor?) {
    guard let anchor = anchor else {
      return nil
    }
    
    self.init(key: key, anchor: anchor)
  }
  
  init(key: String, anchor: HKQueryAnchor) {
    self.key = key
    self.anchor = anchor
  }
}
