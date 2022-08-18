import Foundation
import os.log

class VitalClientDelegate: APIClientDelegate {
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
    
    let components = Set(request.url?.pathComponents ?? []).intersection(Set(["timeseries", "summary"]))
    
    /// For summary and timeseries, we want to gzip its contents
    if components.isEmpty == false && request.httpMethod == "POST"  {
      request.httpBody = try request.httpBody?.gzipped()
      request.setValue("gzip", forHTTPHeaderField: "Content-Encoding")
    }
  }
  
  func shouldClientRetry(_ client: APIClient, withError error: Error) async throws -> Bool {
    guard case .unacceptableStatusCode(401) = error as? APIError else {
      return false
    }
    
    self.logger?.info("Retrying after error: \(error.localizedDescription)")
    
    return true
  }
  
  func client(_ client: APIClient, validateResponse response: HTTPURLResponse, data: Data, task: URLSessionTask) async throws {
    if (200..<300).contains(response.statusCode) {
     return
    }
    
    let networkError = NetworkError(
      url: response.url,
      headers: response.allHeaderFields,
      statusCode: response.statusCode,
      payload: data
    )
    
    print(String(data: data, encoding: .utf8))
    
    self.logger?.error("Failed request with error: \(networkError.localizedDescription)")
        
    throw networkError
  }
}
