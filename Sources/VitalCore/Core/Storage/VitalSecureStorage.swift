import SwiftUI

public class VitalSecureStorage {
  
  private let keychain: KeychainSwift
  private let encoder: JSONEncoder
  private let decoder: JSONDecoder
  
  public init() {
    self.keychain = .init(keyPrefix: "vital_secure_storage_")
    self.encoder = .init()
    self.decoder = .init()
  }

  public func set<T: Encodable>(value: T, key: String) throws {
    let data = try encoder.encode(value)
    keychain.set(data, forKey: key, withAccess: .accessibleAfterFirstUnlock)
  }
  
  public func get<T: Decodable>(key: String) throws -> T? {
    guard let value: Data = keychain.getData(key) else {
      return nil
    }
    
    return try decoder.decode(T.self, from: value)
  }
  
  public func clean(key: String) throws {
    keychain.delete(key)
  }
}

