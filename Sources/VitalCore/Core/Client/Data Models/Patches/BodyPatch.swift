public struct BodyPatch: Encodable {
  public let bodyMass: [QuantitySample]
  public let bodyFatPercentage: [QuantitySample]
  
  public  init(
    bodyMass: [QuantitySample] = [],
    bodyFatPercentage: [QuantitySample] = []
  ) {
    self.bodyMass = bodyMass
    self.bodyFatPercentage = bodyFatPercentage
  }
}
