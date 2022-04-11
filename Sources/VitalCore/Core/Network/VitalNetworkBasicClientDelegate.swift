import Get
import Foundation

class VitalNetworkBasicClientDelegate: APIClientDelegate {
  init() {}
  
  func client(_ client: APIClient, willSendRequest request: inout URLRequest) async throws {
//    request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "content-type")
//    request.allHTTPHeaderFields?.removeValue(forKey: "Accept")
    
    print(request.cURLDescription())
  }

  
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

