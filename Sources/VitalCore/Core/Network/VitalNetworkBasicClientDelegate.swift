import Get
import Foundation

class VitalNetworkBasicClientDelegate: APIClientDelegate {
  init() {}
  
  func client(_ client: APIClient, willSendRequest request: inout URLRequest) async throws {}

  func shouldClientRetry(_ client: APIClient, withError error: Error) async throws -> Bool {
    return false
  }
  
  nonisolated func client(_ client: APIClient, didReceiveInvalidResponse response: HTTPURLResponse, data: Data) -> Error {
    let networkError = NetworkError(
      url: response.url,
      headers: response.allHeaderFields,
      statusCode: response.statusCode,
      payload: data
    )
    
    return networkError
  }
}

