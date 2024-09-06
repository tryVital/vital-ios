import Foundation

public protocol VitalAnyEncodableProtocol: Encodable {
  var wrappedValue: Any { get }
}

public struct VitalAnyEncodable: VitalAnyEncodableProtocol {
  public let wrappedValue: Any
  private let encodeFunction: (Encoder) throws -> Void

  public init<T: Encodable>(_ value: T) {
    self.wrappedValue = value
    self.encodeFunction = { encoder in
      try value.encode(to: encoder)
    }
  }

  public func encode(to encoder: Encoder) throws {
    try encodeFunction(encoder)
  }

  public var dictionary: [String: AnyHashable]? {
    guard let data = try? JSONEncoder().encode(self) else { return nil }
    return (try? JSONSerialization.jsonObject(with: data, options: .allowFragments)).flatMap { $0 as? [String: AnyHashable] }
  }
}


public struct VitalAnyEncodableEquatable: VitalAnyEncodableProtocol, Equatable {
  public let wrappedValue: Any
  private let encodeFunction: (Encoder) throws -> Void
  private let equalityFunction: (VitalAnyEncodableEquatable) -> Bool

  public init<T: Encodable & Equatable>(_ value: T) {
    self.wrappedValue = value
    self.encodeFunction = { encoder in
      try value.encode(to: encoder)
    }
    self.equalityFunction = { other in
      guard let otherValue = other.wrappedValue as? T else { return false }
      return value == otherValue
    }
  }

  public func encode(to encoder: Encoder) throws {
    try encodeFunction(encoder)
  }

  public static func == (lhs: VitalAnyEncodableEquatable, rhs: VitalAnyEncodableEquatable) -> Bool {
    return lhs.equalityFunction(rhs)
  }
}


public struct VitalAnyEncodableHashable: VitalAnyEncodableProtocol, Equatable, Hashable {
  public let wrappedValue: Any
  private let encodeFunction: (Encoder) throws -> Void
  private let equalityFunction: (VitalAnyEncodableHashable) -> Bool
  private let hashFunction: (inout Hasher) -> Void

  public init<T: Encodable & Equatable & Hashable>(_ value: T) {
    self.wrappedValue = value
    self.encodeFunction = { encoder in
      try value.encode(to: encoder)
    }
    self.equalityFunction = { other in
      guard let otherValue = other.wrappedValue as? T else { return false }
      return value == otherValue
    }
    self.hashFunction = { hasher in
      hasher.combine(value)
    }
  }

  public func encode(to encoder: Encoder) throws {
    try encodeFunction(encoder)
  }

  public static func == (lhs: VitalAnyEncodableHashable, rhs: VitalAnyEncodableHashable) -> Bool {
    return lhs.equalityFunction(rhs)
  }

  public func hash(into hasher: inout Hasher) {
    hashFunction(&hasher)
  }
}

public extension Encodable {
  func eraseToAnyEncodable() -> VitalAnyEncodable {
    return VitalAnyEncodable(self)
  }
}

public extension Encodable where Self: Equatable {
  func eraseToAnyEncodable() -> VitalAnyEncodableEquatable {
    return VitalAnyEncodableEquatable(self)
  }
}

public extension Encodable where Self: Equatable & Hashable {
  func eraseToAnyEncodable() -> VitalAnyEncodableHashable {
    return VitalAnyEncodableHashable(self)
  }
}
