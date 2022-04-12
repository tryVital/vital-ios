import KeychainSwift
import Foundation

class VitalKeychain {
  private let keychain = KeychainSwift()
  private let key = "vital_client_jwt"
  private let key_credentials_hash = "vital_client_credentials_hash"
  
  init() {}
  
  func storedJWT() -> StoredJWT? {
    let data = keychain.getData(key)
    
    return data.flatMap {
      try? JSONDecoder().decode(StoredJWT.self, from: $0)
    }
  }
  
  func store(_ storedJWT: StoredJWT) throws -> Void {
    let encoded = try JSONEncoder().encode(storedJWT)
    keychain.set(encoded, forKey: key)
  }
  
  func check(_ credentials: Credentials) -> Void {
    let existingHash = keychain.get(key_credentials_hash)
    let newHash = String(credentials.hashValue)
    
    if existingHash != newHash {
      /// If the new hash is different, it means the credentials were changed.
      /// We should clean the JWT.
      clean()
      
      // Set the new hash
      keychain.set(newHash, forKey: key_credentials_hash)
    }
  }
  
  func clean() -> Void {
    keychain.delete(key)
  }
}
