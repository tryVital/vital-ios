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
