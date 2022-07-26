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
}

public extension Encodable {
  func eraseToAnyEncodable() -> VitalAnyEncodable {
    return .init(self)
  }
}
