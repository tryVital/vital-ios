import Foundation

extension URL {
  func append(_ key: String, value: String) -> URL {
    
    guard var urlComponents = URLComponents(url: self, resolvingAgainstBaseURL: true) else {
      return self
    }
    
    var items: [URLQueryItem] = urlComponents.queryItems ??  []
    let item = URLQueryItem(name: key, value: value)
    
    items.append(item)
    
    urlComponents.queryItems = items
    return urlComponents.url ?? self
  }
}
