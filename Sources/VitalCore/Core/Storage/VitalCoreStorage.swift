import SwiftUI
import HealthKit

class VitalCoreStorage {
    
  private let userDefaults: UserDefaults
  
  init(userDefaults: UserDefaults = .standard) {
    self.userDefaults = userDefaults
    
    let defaultValue: [String: String] = [:]
    userDefaults.register(defaults: defaultValue)
  }
  
  func storeConnectedSource(for userId: UUID, with provider: Provider) {
    let key = "\(userId.uuidString)-\(provider.rawValue)"
    userDefaults.set(true, forKey: key)
  }
  
  func isConnectedSourceStored(for userId: UUID, with provider: Provider) -> Bool {
    let key = "\(userId.uuidString)-\(provider.rawValue)"
    return userDefaults.bool(forKey: key)
  }
  
  func removeConnectedSource(for userId: UUID, with provider: Provider) {
    let key = "\(userId.uuidString)-\(provider.rawValue)"
    userDefaults.removeObject(forKey: key)
  }
}
