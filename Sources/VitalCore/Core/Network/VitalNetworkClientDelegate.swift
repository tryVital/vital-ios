import Get
import Foundation
import KeychainSwift

struct JWT: Decodable {
  let accessToken: String
  let expiresIn: Int
}

struct StoredJWT: Codable {
  let accessToken: String
  let validUntil: Date
}

actor VitalNetworkClientDelegate: APIClientDelegate {
  private var token: StoredJWT?
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
      try? JSONDecoder().decode(StoredJWT.self, from: $0)
    }
  }
  
  private func refreshAndStore() async throws {
    let newToken = try await refresh()
    
    let date = Date()
    let calendar = Calendar.current
    let validUntil = calendar.date(byAdding: .second, value: Int(Double(newToken.expiresIn) * 0.9), to: date)!
    
    let storedToken = StoredJWT.init(accessToken: newToken.accessToken, validUntil: validUntil)
    self.token = storedToken
    
    let encoded = try JSONEncoder().encode(storedToken)
    keychain.set(encoded, forKey: key)
  }
  
  func client(_ client: APIClient, willSendRequest request: inout URLRequest) async throws {
    if token?.validUntil ?? .distantPast < Date()  {
      try await refreshAndStore()
    }
    
    guard let token = self.token else {
      return
    }
    
    request.setValue("Bearer \(token.accessToken)", forHTTPHeaderField: "Authorization")
  }
  
  func shouldClientRetry(_ client: APIClient, withError error: Error) async throws -> Bool {
    
    guard case .unacceptableStatusCode(401) = error as? APIError else {
      return false
    }
    
    try await refreshAndStore()
    return true
  }
}
