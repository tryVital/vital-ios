extension Dictionary {
  mutating func setSafely(_ value: Value?, key: Key) {
    guard let value = value else {
      return
    }
    
    self[key] = value
  }
}
