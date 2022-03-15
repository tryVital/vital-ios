import SwiftUI
import HealthKit

class DateStorage {
  private let userDefaults: UserDefaults
  private let key = "vital_date_activities"
  
  init(userDefaults: UserDefaults = .standard) {
    self.userDefaults = userDefaults
    
    let defaultValue: [String: Date] = [:]
    userDefaults.register(defaults: defaultValue)
  }
  
  func set(_ value: Date) {
    userDefaults.set(value.timeIntervalSinceNow, forKey: key)
  }
  
  func read() -> Date? {
    let timeInterval = userDefaults.double(forKey: key)
    
    /// From the docs: If the value is absent or can't be converted to an integer, 0 will be returned.
    guard timeInterval != 0 else {
      return nil
    }
    
    return Date(timeIntervalSinceNow: timeInterval)
  }
  
  func remove() {
    userDefaults.removeObject(forKey: key)
  }
}

