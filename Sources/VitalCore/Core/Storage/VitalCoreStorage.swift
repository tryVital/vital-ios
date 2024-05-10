import Foundation

// String(describing: VitalResource.vitals(.hearthRate))
private let heartRateFlagOldKey = "vitals(VitalCore.VitalResource.Vitals.hearthRate)"

public struct VitalBackStorage {
  public var isConnectedSourceStored: (String, Provider.Slug) -> Bool
  public var storeConnectedSource: (String, Provider.Slug, Bool) -> Void
  public var storedConnectedSources: (String) -> Set<Provider.Slug>

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
    } storeConnectedSource: { userId, provider, newValue in
      let key = generateKey(userId, provider)
      userDefaults.set(newValue, forKey: key)
    } storedConnectedSources: { userId in
      let slugs = userDefaults.dictionaryRepresentation()
        .compactMap { (key, value) -> Provider.Slug? in
          guard key.hasPrefix(userId) && (value as? Bool) == true else { return nil }
          let components = key.split(separator: "-")
          guard components.count == 2 else { return nil }
          return Provider.Slug(rawValue: String(components[1]))
        }

      return Set(slugs)

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
    } storeConnectedSource: { userId, provider, newValue in
      let key = generateKey(userId, provider)
      storage[key] = newValue
    } storedConnectedSources: { userId in
      let slugs = storage
        .compactMap { (key, value) -> Provider.Slug? in
          guard key.hasPrefix(userId) && value == true else { return nil }
          let components = key.split(separator: "-")
          guard components.count == 2 else { return nil }
          return Provider.Slug(rawValue: String(components[1]))
        }

      return Set(slugs)

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

@_spi(VitalSDKInternals)
public class VitalCoreStorage {
  public static let initialSyncDoneKey = "initial_sync_done"
  private static let hasAskedHealthKitPermissionKey = "hasAskedHealthKitPermission"

  private let storage: VitalBackStorage
  
  public init(storage: VitalBackStorage) {
    self.storage = storage
  }

  func storedConnectedSources(for userId: String) -> Set<Provider.Slug> {
    storage.storedConnectedSources(userId)
  }

  func storeConnectedSource(for userId: String, with provider: Provider.Slug, newValue: Bool = true) {
    storage.storeConnectedSource(userId, provider, newValue)
  }

  func isConnectedSourceStored(for userId: String, with provider: Provider.Slug) -> Bool {
    return storage.isConnectedSourceStored(userId, provider)
  }

  public func hasAskedHealthKitPermission() -> Bool {
    return storage.read(Self.hasAskedHealthKitPermissionKey) == Data([0x01])
      || storage.read(Self.initialSyncDoneKey) == Data([0x01])
  }

  public func setAskedHealthKitPermission(_ newValue: Bool) {
    storage.store(Data([newValue ? 0x01 : 0x00]), Self.hasAskedHealthKitPermissionKey)
  }

  func clean() -> Void {
    return storage.clean()
  }
}
