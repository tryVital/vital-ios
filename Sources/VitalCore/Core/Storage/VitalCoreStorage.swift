import SwiftUI
import HealthKit

struct Storage {
  var isConnectedSourceStored: (UUID, Provider) -> Bool
  var storeConnectedSource: (UUID, Provider) -> Void
  var clean: () -> Void
  
  static var live: Storage {
    
    let userDefaults = UserDefaults(suiteName: "tryVital")!
    
    let defaultValue: [String: String] = [:]
    userDefaults.register(defaults: defaultValue)
    
    let generateKey: (UUID, Provider) -> String = { userId, provider in
      return "\(userId.uuidString)-\(provider.rawValue)"
    }
    
    return .init { userId, provider in
      let key = generateKey(userId, provider)
      return userDefaults.bool(forKey: key)
    } storeConnectedSource: { userId, provider in
      let key = generateKey(userId, provider)
      userDefaults.set(true, forKey: key)
    } clean: {
      userDefaults.removePersistentDomain(forName: "tryVital")
    }
  }
  
  static var debug: Storage {
    
    var storage: [String: Bool] = [:]
    
    let generateKey: (UUID, Provider) -> String = { userId, provider in
      return "\(userId.uuidString)-\(provider.rawValue)"
    }
    
    return .init { userId, provider in
      let key = generateKey(userId, provider)
      return storage[key] != nil
    } storeConnectedSource: { userId, provider in
      let key = generateKey(userId, provider)
      storage[key] = true
    } clean: {
      storage = [:]
    }
  }

}

class VitalCoreStorage {
  private let storage: Storage
  
  init(storage: Storage = .live) {
    self.storage = storage
  }
  
  func storeConnectedSource(for userId: UUID, with provider: Provider) {
    self.storage.storeConnectedSource(userId, provider)
  }
  
  func isConnectedSourceStored(for userId: UUID, with provider: Provider) -> Bool {
    return self.storage.isConnectedSourceStored(userId, provider)
  }
  
  func clean() -> Void {
    return self.storage.clean()
  }
}
