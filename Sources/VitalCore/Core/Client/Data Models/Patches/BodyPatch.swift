public struct BodyPatch: Equatable, Encodable {
  public let bodyMass: [LocalQuantitySample]
  public let bodyFatPercentage: [LocalQuantitySample]
  
  public  init(
    bodyMass: [LocalQuantitySample] = [],
    bodyFatPercentage: [LocalQuantitySample] = []
  ) {
    self.bodyMass = bodyMass
    self.bodyFatPercentage = bodyFatPercentage
  }
}
