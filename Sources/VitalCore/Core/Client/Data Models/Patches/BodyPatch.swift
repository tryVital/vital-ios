public struct BodyPatch: Equatable, Encodable {
  public let bodyMass: [LocalQuantitySample]
  public let bodyFatPercentage: [LocalQuantitySample]
  public let bodyMassIndex: [LocalQuantitySample]
  public let waistCircumference: [LocalQuantitySample]
  public let leanBodyMass: [LocalQuantitySample]

  @TimeZones
  public var timeZones: [GregorianCalendar.FloatingDate: String]

  public init(
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
    self._timeZones = TimeZones(wrappedValue: timeZones)
  }

  @propertyWrapper
  public struct TimeZones: Equatable, Encodable {
    public let wrappedValue: [GregorianCalendar.FloatingDate: String]

    public init(wrappedValue: [GregorianCalendar.FloatingDate : String]) {
      self.wrappedValue = wrappedValue
    }

    public func encode(to encoder: any Encoder) throws {
      var container = encoder.unkeyedContainer()

      for (date, zoneId) in wrappedValue {
        var inner = container.nestedUnkeyedContainer()
        try inner.encode(date)
        try inner.encode(zoneId)
      }
    }
  }
}
