extension Array {
  mutating func appendOptional(_ value: Element?) {
    guard let value = value else {
      return
    }
    
    self.append(value)
  }
}

