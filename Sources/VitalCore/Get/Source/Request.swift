// The MIT License (MIT)
//
// Copyright (c) 2021-2022 Alexander Grebenyuk (github.com/kean).

import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// An HTTP network request.
struct Request<Response>: @unchecked Sendable {
  /// HTTP method, e.g. "GET".
  var method: HTTPMethod
  /// Resource URL. Can be either absolute or relative.
  var url: URL?
  /// Request query items.
  var query: [(String, String?)]?
  /// Request body.
  var body: Encodable?
  /// Request headers to be added to the request.
  var headers: [String: String]?
  /// ID provided by the user. Not used by the API client.
  var id: String?
  
  /// Initialiazes the request with the given parameters.
  init(
    url: URL,
    method: HTTPMethod = .get,
    query: [(String, String?)]? = nil,
    body: Encodable? = nil,
    headers: [String: String]? = nil,
    id: String? = nil
  ) {
    self.method = method
    self.url = url
    self.query = query
    self.headers = headers
    self.body = body
    self.id = id
  }
  
  /// Initializes the request with the given parameters.
  init(
    path: String,
    method: HTTPMethod = .get,
    query: [(String, String?)]? = nil,
    body: Encodable? = nil,
    headers: [String: String]? = nil,
    id: String? = nil
  ) {
    self.method = method
    self.url = URL(string: path.isEmpty ? "/" : path)
    self.query = query
    self.headers = headers
    self.body = body
    self.id = id
  }
  
  private init(optionalUrl: URL?, method: HTTPMethod) {
    self.url = optionalUrl
    self.method = method
  }
  
  /// Changes the response type keeping the rest of the request parameters.
  func withResponse<T>(_ type: T.Type) -> Request<T> {
    var copy = Request<T>(optionalUrl: url, method: method)
    copy.query = query
    copy.body = body
    copy.headers = headers
    copy.id = id
    return copy
  }
}

extension Request where Response == Void {
  /// Initialiazes the request with the given parameters.
  init(
    url: URL,
    method: HTTPMethod = .get,
    query: [(String, String?)]? = nil,
    body: Encodable? = nil,
    headers: [String: String]? = nil,
    id: String? = nil
  ) {
    self.method = method
    self.url = url
    self.query = query
    self.headers = headers
    self.body = body
    self.id = id
  }
  
  /// Initialiazes the request with the given parameters.
  init(
    path: String,
    method: HTTPMethod = .get,
    query: [(String, String?)]? = nil,
    body: Encodable? = nil,
    headers: [String: String]? = nil,
    id: String? = nil
  ) {
    self.method = method
    self.url = URL(string: path.isEmpty ? "/" : path)
    self.query = query
    self.headers = headers
    self.body = body
    self.id = id
  }
}

struct HTTPMethod: RawRepresentable, Hashable, ExpressibleByStringLiteral {
  let rawValue: String
  
  init(rawValue: String) {
    self.rawValue = rawValue
  }
  
  init(stringLiteral value: String) {
    self.rawValue = value
  }
  
  static let get: HTTPMethod = "GET"
  static let post: HTTPMethod = "POST"
  static let patch: HTTPMethod = "PATCH"
  static let put: HTTPMethod = "PUT"
  static let delete: HTTPMethod = "DELETE"
  static let options: HTTPMethod = "OPTIONS"
  static let head: HTTPMethod = "HEAD"
  static let trace: HTTPMethod = "TRACE"
}
