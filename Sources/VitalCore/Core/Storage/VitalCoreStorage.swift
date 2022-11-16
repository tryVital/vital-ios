import SwiftUI
import HealthKit

public struct VitalBackStorage {
  public var isConnectedSourceStored: (UUID, Provider) -> Bool
  public var storeConnectedSource: (UUID, Provider) -> Void
  
  public var flagResource: (VitalResource) -> Void
  public var isResourceFlagged: (VitalResource) -> Bool
  
  public var store: (Data, String) -> Void
  public var read: (String) -> Data?
  
  public var storeDate: (Date, String) -> Void
  public var readDate: (String) -> Date?
  
  public var remove: (String) -> Void
  
  public var clean: () -> Void
  
  public static var live: VitalBackStorage {
    
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
    } flagResource: { resource in
      userDefaults.set(true, forKey: String(describing: resource))
    } isResourceFlagged: { resource in
      return userDefaults.bool(forKey: String(describing: resource))
    } store: { data, key in
      userDefaults.set(data, forKey: key)
    } read: { key in
      userDefaults.data(forKey: key)
    } storeDate: { date, key in
      userDefaults.set(date.timeIntervalSince1970, forKey: key)
    } readDate: { key in
      let value: Double? = userDefaults.double(forKey: key)
      if value == 0 {
        return nil
      }
      return value.map(Date.init(timeIntervalSince1970:))
    } remove: { key in
      userDefaults.removeObject(forKey: key)
    } clean: {
      userDefaults.removePersistentDomain(forName: "tryVital")
    }
  }
  
  static var debug: VitalBackStorage {
    
    var storage: [String: Bool] = [:]
    var dataStorage: [String: Data] = [:]

    var dateStorage: [String: Double] = [:]

    let generateKey: (UUID, Provider) -> String = { userId, provider in
      return "\(userId.uuidString)-\(provider.rawValue)"
    }
    
    return .init { userId, provider in
      let key = generateKey(userId, provider)
      return storage[key] != nil
    } storeConnectedSource: { userId, provider in
      let key = generateKey(userId, provider)
      storage[key] = true
    } flagResource: { resource in
      storage[String(describing: resource)] = true
    } isResourceFlagged: { resource in
      return storage[String(describing: resource)] != nil
    } store: { data, key in
      dataStorage[key] = data
    } read: { key in
      return dataStorage[key]
    } storeDate: { date, key in
      dateStorage[key] = date.timeIntervalSince1970
    } readDate: { key in
      let value = dateStorage[key]
      return value.map(Date.init(timeIntervalSince1970:))
    } remove: { key in
      dataStorage.removeValue(forKey: key)
    } clean: {
      storage = [:]
      dataStorage = [:]
    }
  }
}

class VitalCoreStorage {
  private let storage: VitalBackStorage
  
  init(storage: VitalBackStorage) {
    self.storage = storage
  }
  
  func storeConnectedSource(for userId: UUID, with provider: Provider) {
    storage.storeConnectedSource(userId, provider)
  }
  
  func isConnectedSourceStored(for userId: UUID, with provider: Provider) -> Bool {
    return storage.isConnectedSourceStored(userId, provider)
  }
  
  func clean() -> Void {
    return storage.clean()
  }
}
