import Get
import Foundation
import KeychainSwift

struct JWT: Codable {
  let accessToken: String
  let expiresIn: Date
}

actor VitalNetworkClientDelegate: APIClientDelegate {
  private var token: JWT?
  private let key = "vital_client_jwt"
  private let refresh: () async throws -> JWT
  private let keychain: KeychainSwift
  
  init(
    refresh: @escaping () async throws -> JWT
  ) {
    self.refresh = refresh
    self.keychain = KeychainSwift()
    
    let data = self.keychain.getData(key)
    
    self.token = data.flatMap {
      try? JSONDecoder().decode(JWT.self, from: $0)
    }
  }
  
  func client(_ client: APIClient, willSendRequest request: inout URLRequest) async throws {
    
    if let token = token, token.expiresIn < Date() {
      request.setValue("Bearer: \(token.accessToken)", forHTTPHeaderField: "Authorization")
      
    } else {
      let newToken = try await refresh()
      self.token = newToken

      let encoded = try JSONEncoder().encode(newToken)
      keychain.set(encoded, forKey: key)
      
      request.setValue("Bearer: \(newToken.accessToken)", forHTTPHeaderField: "Authorization")
    }
  }
  
  func shouldClientRetry(_ client: APIClient, withError error: Error) async throws -> Bool {
    return true
  }
}
