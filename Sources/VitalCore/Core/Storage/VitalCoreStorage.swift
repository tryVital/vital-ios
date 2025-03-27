import Foundation

public struct VitalBackStorage {
  public var isConnectedSourceStored: (String, Provider.Slug) -> Bool
  public var storeConnectedSource: (String, Provider.Slug) -> Void
  
  public var flagResource: (VitalResource) -> Void
  public var isResourceFlagged: (VitalResource) -> Bool

  public var store: (Data, String) -> Void
  public var read: (String) -> Data?

  public var storeDouble: (Double, String) -> Void
  public var readDouble: (String) -> Double?

  public var storeDate: (Date, String) -> Void
  public var readDate: (String) -> Date?
  
  public var remove: (String) -> Void
  
  public var clean: () -> Void

  public var dump: () -> [String: Any?]
  
  public static let live: VitalBackStorage = {

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
      userDefaults.set(true, forKey: resource.storageWriteKey)

    } isResourceFlagged: { resource in
      let keys = resource.storageReadKeys
      return keys.contains(where: userDefaults.bool(forKey:))

    } store: { data, key in
      userDefaults.set(data, forKey: key)
    } read: { key in
      userDefaults.data(forKey: key)
    } storeDouble: { value, key in
      userDefaults.set(value, forKey: key)
    } readDouble: { key in
      userDefaults.double(forKey: key)
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
    } dump: {
      userDefaults.persistentDomain(forName: "tryVital") ?? [:]
    }
  }()

  public static var debug: VitalBackStorage {
    
    var storage: [String: Bool] = [:]
    var dataStorage: [String: Data] = [:]
    var doubleStorage: [String: Double] = [:]
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
      storage[resource.storageWriteKey] = true
    } isResourceFlagged: { resource in
      return resource.storageReadKeys.contains { storage[$0] == true }
    } store: { data, key in
      dataStorage[key] = data
    } read: { key in
      return dataStorage[key]
    } storeDouble: { value, key in
      doubleStorage[key] = value
    } readDouble: { key in
      doubleStorage[key]
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
    } dump: {
      return [:]
    }
  }
}

public class VitalCoreStorage {
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
