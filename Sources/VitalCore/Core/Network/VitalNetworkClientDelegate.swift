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
  
  private func refreshAndStore() async throws {
    let newToken = try await refresh()
    self.token = newToken
    
    let encoded = try JSONEncoder().encode(newToken)
    keychain.set(encoded, forKey: key)
  }
  
  func client(_ client: APIClient, willSendRequest request: inout URLRequest) async throws {
    print(request.url)
    print(String(data: request.httpBody!, encoding: .utf8))
    if token?.expiresIn ?? .distantPast < Date() {
      try await refreshAndStore()
    }
    
    guard let token = self.token else {
      return
    }
    
    request.setValue("Bearer: \(token.accessToken)", forHTTPHeaderField: "Authorization")
  }
  
  func shouldClientRetry(_ client: APIClient, withError error: Error) async throws -> Bool {
    print(error)
    guard case .unacceptableStatusCode(401) = error as? APIError else {
      return false
    }
    
    try await refreshAndStore()
    return true
  }
}
