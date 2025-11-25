import Foundation

public struct Keychain {
  var set: (Data, String) -> Void
  var get: (String) throws -> Data?
  var clean: (String) -> Void

  public static var live: Keychain {
    return makeLive(synchronizable: false)
  }
  public static func makeLive(synchronizable: Bool) -> Keychain {
    let keychain: KeychainSwift = .init(keyPrefix: "vital_secure_storage_")
    keychain.synchronizable = synchronizable

    return .init { data, key in
      keychain.set(data, forKey: key, withAccess: .accessibleAfterFirstUnlock)
    } get: { key in
      try keychain.getData(key)
    } clean: { key in
      keychain.delete(key)
    }
  }
  
  static var debug: Keychain {
    var storage: [String: Data] = [:]
    
    return .init { data, key in
      storage[key] = data
    } get: { key in
      storage[key]
    } clean: { key in
      storage.removeValue(forKey: key)
    }
  }
}

public class VitalSecureStorage: @unchecked Sendable {
  
  private let keychain: Keychain
  private let encoder: JSONEncoder
  private let decoder: JSONDecoder
  
  public init(keychain: Keychain) {
    self.keychain = keychain
    self.encoder = .init()
    self.decoder = .init()
  }

  public func set<T: Encodable>(value: T, key: String) throws {
    let data = try encoder.encode(value)
    keychain.set(data, key)
  }
  
  public func get<T: Decodable>(key: String) throws -> T? {
    guard let value: Data = try keychain.get(key) else {
      return nil
    }
    
    return try decoder.decode(T.self, from: value)
  }

  public func clean(key: String) {
    keychain.clean(key)
  }
}

