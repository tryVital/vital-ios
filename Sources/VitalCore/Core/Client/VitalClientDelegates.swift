import Foundation
import os.log

enum VitalClientAuthStrategy {
  case apiKey(String)
  case jwt(VitalJWTAuth)
}

class VitalClientDelegate: APIClientDelegate {
  private let environment: Environment
  private let authStrategy: VitalClientAuthStrategy

  init(
    environment: Environment,
    authStrategy: VitalClientAuthStrategy
  ) {
    self.environment = environment
    self.authStrategy = authStrategy
  }

  func client<T>(_ client: APIClient, encoderForRequest request: Request<T>) -> JSONEncoder? {
    VitalPersistentLogger.shared?.log(request)

    // Use default implementation
    return nil
  }
  
  func client(_ client: APIClient, willSendRequest request: inout URLRequest) async throws {

    switch authStrategy {
    case let .apiKey(apiKey):
      request.setValue(apiKey, forHTTPHeaderField: "x-vital-api-key")

    case let .jwt(auth):
      let accessToken = try await auth.withAccessToken { $0 }
      request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "authorization")
    }

    request.setValue(sdk_version, forHTTPHeaderField: "x-vital-ios-sdk-version")

    let components = Set(request.url?.pathComponents ?? []).intersection(Set(["timeseries", "summary"]))
    
    /// For summary and timeseries, we want to gzip its contents
    if components.isEmpty == false && request.httpMethod == "POST"  {
      request.httpBody = try request.httpBody?.gzipped()
      request.setValue("gzip", forHTTPHeaderField: "Content-Encoding")
    }

    let requestCopy = request
    VitalLogger.requests.info("\(requestCopy.logPrefix, privacy: .public) (\(requestCopy.httpBody?.count ?? 0, privacy: .public) bytes)")
  }
  
  func client(_ client: APIClient, shouldRetry task: URLSessionTask, error: Error, attempts: Int) async throws -> Bool {
    guard
      attempts <= 3,
      case .unacceptableStatusCode(401) = error as? APIError
    else { return false }
    
    switch authStrategy {
    case .apiKey:
      // API Key revoked
      return false

    case let .jwt(auth):
      try await auth.refreshToken()
      return true
    }
  }

  func client(_ client: APIClient, validateResponse response: HTTPURLResponse, data: Data, task: URLSessionTask) throws {
    if (200..<300).contains(response.statusCode) {
     return
    }
    
    let networkError = NetworkError(response: response, data: data)

    let request = task.currentRequest ?? task.originalRequest
    VitalLogger.requests.error("\(request?.logPrefix ?? "", privacy: .public) Error response: \(networkError.localizedDescription, privacy: .public)")

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
    
    let networkError = NetworkError(response: response, data: data)
    throw networkError
  }
}

extension URLRequest {
  fileprivate var logPrefix: String {
    "[\(self.httpMethod ?? "") \(self.url?.absoluteString ?? "")]"
  }
}
