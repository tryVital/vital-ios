import Foundation

public struct NetworkError: Error, LocalizedError {
  public let url: URL?
  public let headers: [AnyHashable: Any]
  public let statusCode: Int
  public let payload: Data?
  
  
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
