struct AnyEncodable: Encodable {
  private let encode: (Encoder) throws -> Void
  
  init(_ encodable: Encodable) {
    self.encode = { encoder in
      try encodable.encode(to: encoder)
    }
  }
  
  func encode(to encoder: Encoder) throws {
    try encode(encoder)
  }
}
