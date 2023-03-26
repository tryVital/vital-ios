import HealthKit

extension Array {
  mutating func appendOptional(_ value: Element?) {
    guard let value = value else {
      return
    }
    
    self.append(value)
  }
}

extension Array where Element == HKSample {
  func filter(by sourceName: String) -> Array<HKSample> {
    return self.filter { sample in
      sample.sourceRevision.source.bundleIdentifier == sourceName
    }
  }
}

extension Collection where Element: OptionalProtocol {
  func filterNotNil() -> [Element.Wrapped] {
    compactMap { $0.wrapped }
  }
}

internal protocol OptionalProtocol {
  associatedtype Wrapped
  var wrapped: Wrapped? { get }
}

extension Optional: OptionalProtocol {
  internal var wrapped: Wrapped? { self }
}
