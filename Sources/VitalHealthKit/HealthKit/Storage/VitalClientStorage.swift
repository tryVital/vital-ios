import SwiftUI
import HealthKit
import VitalCore

class VitalStorage {
  
  private let prefix = "vital_anchor_"
  private let flag = "vital_anchor_"
  private let connectedSourceCreated = "vital_health_kit_created"

  private let userDefaults: UserDefaults
  
  init(userDefaults: UserDefaults = .standard) {
    self.userDefaults = userDefaults
        
    let defaultValue: [String: String] = [:]
    userDefaults.register(defaults: defaultValue)
  }
  
  func storeConnectedSourceCreated() {
    userDefaults.set(true, forKey: connectedSourceCreated)
  }
  
  func isConnectedSourceCreated() -> Bool {
    userDefaults.bool(forKey: connectedSourceCreated)
  }
  
  func removeConnectedSourceCreated() {
    userDefaults.removeObject(forKey: connectedSourceCreated)
  }
  
  func storeFlag(for resource: VitalResource) {
    userDefaults.set(true, forKey: String(describing: resource))
  }
  
  func readFlag(for resource: VitalResource) -> Bool {
    return userDefaults.bool(forKey: String(describing: resource))
  }
  
  func store(entity: StoredEntity) {
    let prefixedKey = prefix + entity.key
    
    switch entity {
      case .anchor(_, let anchor):
        guard let data = try? NSKeyedArchiver.archivedData(withRootObject: anchor, requiringSecureCoding: true) else {
          return
        }
        
        let encoded = data.base64EncodedString()
        userDefaults.set(encoded, forKey: prefixedKey)
        
      case .date(_, let date):
        userDefaults.set(date.timeIntervalSinceNow, forKey: prefixedKey)
    }
  }
  
  func read(key: String) -> StoredEntity? {
    
    let prefixedKey = prefix + key
    let timeInterval = userDefaults.double(forKey: prefixedKey)
    
    if timeInterval != 0 {
      /// From the docs: If the value is absent or can't be converted to an integer, 0 will be returned.
      return .date(key, Date(timeIntervalSinceNow: timeInterval))
    }
    
    if let storedString = userDefaults.string(forKey: prefixedKey),
       let data = Data(base64Encoded: storedString) {
      
      let anchor = try? NSKeyedUnarchiver.unarchivedObject(ofClass: HKQueryAnchor.self, from: data)
      return anchor.map { StoredEntity.anchor(key, $0) }
    }
    
    return nil
  }

  func remove(key: String) {
    userDefaults.removeObject(forKey: prefix + key)
  }
}

enum StoredEntity {
  case anchor(String, HKQueryAnchor)
  case date(String, Date)
  
  var anchor: HKQueryAnchor? {
    switch self {
      case let .anchor(_, anchor):
        return anchor
      case .date:
        return nil
    }
  }
  
  var date: Date? {
    switch self {
      case .anchor:
        return nil
      case let .date(_, date):
        return date
    }
  }
  
  var key: String {
    switch self {
      case let .anchor(key, _):
        return key
      case let .date(key, _):
        return key
    }
  }
}
