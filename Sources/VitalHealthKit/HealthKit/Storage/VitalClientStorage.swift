import SwiftUI
import HealthKit



class VitalStorage {

  static let activitiesKey = "activities"
  
  private let prefix = "vital_anchor_"
  private let userDefaults: UserDefaults
  
  init(userDefaults: UserDefaults = .standard) {
    self.userDefaults = userDefaults
        
    let defaultValue: [String: String] = [:]
    userDefaults.register(defaults: defaultValue)
  }
  
  func store(entity: StoredEntity) {
    switch entity {
      case .anchor(let key, let anchor):
        guard let data = try? NSKeyedArchiver.archivedData(withRootObject: anchor, requiringSecureCoding: true) else {
          return
        }
        
        let encoded = data.base64EncodedString()
        userDefaults.set(encoded, forKey: key)
        
        
      case .date(let key, let date):
        userDefaults.set(date.timeIntervalSinceNow, forKey: key)
    }
  }
  
  func read(key: String) -> StoredEntity? {
    
    let timeInterval = userDefaults.double(forKey: key)
    
    if timeInterval != 0 {
      /// From the docs: If the value is absent or can't be converted to an integer, 0 will be returned.
      return .date(key, Date(timeIntervalSinceNow: timeInterval))
    }
    
    if let storedString = userDefaults.string(forKey: prefix + key),
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
}
