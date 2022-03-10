import SwiftUI
import HealthKit

class AnchorStorage {
  private let userDefaults: UserDefaults
  
  init(userDefaults: UserDefaults = .standard) {
    self.userDefaults = userDefaults
    
    let defaultValue: [String: String] = [:]
    userDefaults.register(defaults: defaultValue)
  }
  
  func set(_ value: HKQueryAnchor, forKey key: String) {
    guard let data = try? NSKeyedArchiver.archivedData(withRootObject: value, requiringSecureCoding: true) else {
      return
    }
    
    let encoded = data.base64EncodedString()
    userDefaults.set(encoded, forKey: key)
  }
  
  func read(key: String) -> HKQueryAnchor? {
    guard
      let storedString = userDefaults.string(forKey: key),
      let data = Data(base64Encoded: storedString)
    else {
      return nil
    }
    
    return try? NSKeyedUnarchiver.unarchivedObject(ofClass: HKQueryAnchor.self, from: data)
  }
  
  func remove(key: String) {
    userDefaults.removeObject(forKey: key)
  }
}
