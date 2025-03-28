public struct BodyPatch: Equatable, Encodable {
  public let bodyMass: [LocalQuantitySample]
  public let bodyFatPercentage: [LocalQuantitySample]
  public let bodyMassIndex: [LocalQuantitySample]
  public let waistCircumference: [LocalQuantitySample]
  public let leanBodyMass: [LocalQuantitySample]

  public let timeZones: [GregorianCalendar.FloatingDate: String]

  public  init(
    bodyMass: [LocalQuantitySample] = [],
    bodyFatPercentage: [LocalQuantitySample] = [],
    bodyMassIndex: [LocalQuantitySample] = [],
    waistCircumference: [LocalQuantitySample] = [],
    leanBodyMass: [LocalQuantitySample] = [],
    timeZones: [GregorianCalendar.FloatingDate: String]
  ) {
    self.bodyMass = bodyMass
    self.bodyFatPercentage = bodyFatPercentage
    self.bodyMassIndex = bodyMassIndex
    self.waistCircumference = waistCircumference
    self.leanBodyMass = leanBodyMass
    self.timeZones = timeZones
  }
}
