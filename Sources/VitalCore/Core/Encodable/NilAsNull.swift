import Foundation

@propertyWrapper
public struct NilAsNull<Value: Codable>: Codable {
  public var wrappedValue: Value?

  public init(wrappedValue: Value? = nil) {
    self.wrappedValue = wrappedValue
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    if container.decodeNil() {
      wrappedValue = nil
    } else {
      wrappedValue = try container.decode(Value.self)
    }
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    if let value = wrappedValue {
      try container.encode(value)
    } else {
      try container.encodeNil()
    }
  }
}

extension NilAsNull: Equatable where Value: Equatable {}

