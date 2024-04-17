import Foundation

// String(describing: VitalResource.vitals(.hearthRate))
private let heartRateFlagOldKey = "vitals(VitalCore.VitalResource.Vitals.hearthRate)"

public struct VitalBackStorage {
  public var isConnectedSourceStored: (String, Provider.Slug) -> Bool
  public var storeConnectedSource: (String, Provider.Slug) -> Void
  
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
    
    let generateKey: (String, Provider.Slug) -> String = { userId, provider in
      return "\(userId)-\(provider.rawValue)"
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
      if resource == .vitals(.heartRate) {
        return userDefaults.bool(forKey: String(describing: resource))
          || userDefaults.bool(forKey: heartRateFlagOldKey)
      }

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
  
  public static var debug: VitalBackStorage {
    
    var storage: [String: Bool] = [:]
    var dataStorage: [String: Data] = [:]

    var dateStorage: [String: Double] = [:]

    let generateKey: (String, Provider.Slug) -> String = { userId, provider in
      return "\(userId)-\(provider.rawValue)"
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
  
  func storeConnectedSource(for userId: String, with provider: Provider.Slug) {
    storage.storeConnectedSource(userId, provider)
  }
  
  func isConnectedSourceStored(for userId: String, with provider: Provider.Slug) -> Bool {
    return storage.isConnectedSourceStored(userId, provider)
  }
  
  func clean() -> Void {
    return storage.clean()
  }
}
