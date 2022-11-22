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
    request.setValue(sdk_version, forHTTPHeaderField: "x-vital-ios-sdk-version")

    let components = Set(request.url?.pathComponents ?? []).intersection(Set(["timeseries", "summary"]))
    
    /// For summary and timeseries, we want to gzip its contents
    if components.isEmpty == false && request.httpMethod == "POST"  {
      request.httpBody = try request.httpBody?.gzipped()
      request.setValue("gzip", forHTTPHeaderField: "Content-Encoding")
    }
  }
  
  func client(_ client: APIClient, shouldRetry task: URLSessionTask, error: Error, attempts: Int) async throws -> Bool {
    guard case .unacceptableStatusCode(401) = error as? APIError else {
      return false
    }
    
    self.logger?.info("Retrying after error: \(error.localizedDescription)")
    
    return true
  }
  
  func client(_ client: APIClient, validateResponse response: HTTPURLResponse, data: Data, task: URLSessionTask) throws {
    if (200..<300).contains(response.statusCode) {
     return
    }
    
    let networkError = NetworkError(
      url: response.url,
      headers: response.allHeaderFields,
      statusCode: response.statusCode,
      payload: data
    )
        
    self.logger?.error("Failed request with error: \(networkError.localizedDescription)")
    throw networkError
  }
}

class VitalBaseClientDelegate: APIClientDelegate {
  func client(_ client: APIClient, willSendRequest request: inout URLRequest) async throws {
    request.setValue(sdk_version, forHTTPHeaderField: "x-vital-ios-sdk-version")
  }
  
  func client(_ client: APIClient, validateResponse response: HTTPURLResponse, data: Data, task: URLSessionTask) throws {
    if (200..<300).contains(response.statusCode) {
      return
    }
    
    let networkError = NetworkError(
      url: response.url,
      headers: response.allHeaderFields,
      statusCode: response.statusCode,
      payload: data
    )
    
    throw networkError
  }
}
