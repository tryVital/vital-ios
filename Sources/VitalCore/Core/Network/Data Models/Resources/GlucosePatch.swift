public struct GlucosePatch: Encodable {
  public let glucose: [QuantitySample]
  
  public init(glucose: [QuantitySample]) {
    self.glucose = glucose
  }
}
