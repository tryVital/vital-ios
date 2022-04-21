import Get
import Foundation
import KeychainSwift
import os.log

struct JWT: Decodable {
  let accessToken: String
  let expiresIn: Int
}

struct StoredJWT: Codable {
  let accessToken: String
  let validUntil: Date
  let environment: Environment
}

actor VitalNetworkClientDelegate: APIClientDelegate {
  private var token: StoredJWT?
  private let refresh: () async throws -> JWT
  private let keychain: VitalKeychain
  private let environment: Environment
  private let logger: Logger?

  init(
    refresh: @escaping () async throws -> JWT,
    keychain: VitalKeychain,
    environment: Environment,
    logger: Logger? = nil
  ) {
    self.refresh = refresh
    self.keychain = keychain
    self.environment = environment
    self.logger = logger
    
    let token = keychain.storedJWT()
    
    if token?.environment == environment {
      self.token = token
    } else {
      keychain.clean()
    }
  }
  
  private func refreshAndStore() async throws {
    let newToken = try await refresh()
    
    let date = Date()
    let calendar = Calendar.current
    let validUntil = calendar.date(byAdding: .second, value: Int(Double(newToken.expiresIn) * 0.9), to: date)!
    
    let storedToken = StoredJWT(accessToken: newToken.accessToken, validUntil: validUntil, environment: self.environment)
    self.token = storedToken
    
    try keychain.store(storedToken)
  }
  
  func client(_ client: APIClient, willSendRequest request: inout URLRequest) async throws {
    if token?.validUntil ?? .distantPast < Date()  {
      self.logger?.info("Refreshing token")
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
    
    self.logger?.info("Retrying after error: \(error.localizedDescription)")
    
    try await refreshAndStore()
    return true
  }
  
  nonisolated func client(_ client: APIClient, didReceiveInvalidResponse response: HTTPURLResponse, data: Data) -> Error {
    let networkError = NetworkError(
      url: response.url,
      headers: response.allHeaderFields,
      statusCode: response.statusCode,
      payload: data
    )
    
    self.logger?.error("Failed request with error: \(networkError.localizedDescription)")
        
    return networkError
  }
}
