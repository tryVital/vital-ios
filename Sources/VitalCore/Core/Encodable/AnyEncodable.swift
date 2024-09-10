import Foundation

public struct VitalAnyEncodable: Encodable {
  private let encode: (Encoder) throws -> Void

  public init(_ encodable: Encodable) {
    self.encode = { encoder in
      try encodable.encode(to: encoder)
    }
  }

  public func encode(to encoder: Encoder) throws {
    try encode(encoder)
  }

  public var dictionary: [String: AnyHashable]? {
    guard let data = try? JSONEncoder().encode(self) else { return nil }
    return (try? JSONSerialization.jsonObject(with: data, options: .allowFragments)).flatMap { $0 as? [String: AnyHashable] }
  }
}

public extension Encodable {
  func eraseToAnyEncodable() -> VitalAnyEncodable {
    return .init(self)
  }
}
