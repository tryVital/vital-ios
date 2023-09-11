import Foundation

public struct NetworkError: Error, LocalizedError, CustomStringConvertible {
  public let url: URL?
  public let headers: [AnyHashable: Any]
  public let statusCode: Int
  public let payload: Data?

  public init(url: URL?, headers: [AnyHashable : Any], statusCode: Int, payload: Data?) {
    self.url = url
    self.headers = headers
    self.statusCode = statusCode
    self.payload = payload
  }

  public init(response: HTTPURLResponse, data: Data?) {
    self.init(
      url: response.url,
      headers: response.allHeaderFields,
      statusCode: response.statusCode,
      payload: data
    )
  }
  
  public var description: String {
    let data: String = payload.flatMap { String(data: $0, encoding: .utf8) } ?? "n/a"
      
    return """
           
            ❌❌❌❌❌❌❌
            URL: \(url?.absoluteString ?? "n/a")\n
            headers: \(headers)\n
            Status code: \(statusCode)\n
            payload: \(data))
            ❌❌❌❌❌❌❌
           
           """
  }
  
  public var errorDescription: String? {
    return description
  }
}
