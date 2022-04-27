import Get
import Foundation
import KeychainSwift
import os.log


actor VitalNetworkClientDelegate: APIClientDelegate {
  private let environment: Environment
  private let logger: Logger?
  private let apiKey: String

  init(
    environment: Environment,
    logger: Logger? = nil,
    apiKey: String
  ) {
    self.environment = environment
    self.logger = logger
    self.apiKey = apiKey
  }
  
  func client(_ client: APIClient, willSendRequest request: inout URLRequest) async throws {
    request.setValue(apiKey, forHTTPHeaderField: "x-vital-api-key")
    print(request.cURLDescription())
  }
  
  func shouldClientRetry(_ client: APIClient, withError error: Error) async throws -> Bool {
    guard case .unacceptableStatusCode(401) = error as? APIError else {
      return false
    }
    
    self.logger?.info("Retrying after error: \(error.localizedDescription)")
    
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
