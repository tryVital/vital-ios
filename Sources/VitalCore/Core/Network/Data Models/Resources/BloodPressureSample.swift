import Foundation

public struct BloodPressureSample: Equatable, Hashable, Encodable {
  public let systolic: Double
  public let diastolic: Double
  public let pulseRate: Double
  
  public let date: Date
  public let units: String
  public let type: String?
  
  public init(
    systolic: Double,
    diastolic: Double,
    pulseRate: Double,
    date: Date,
    units: String,
    type: String? = nil
  ) {
    self.systolic = systolic
    self.diastolic = diastolic
    self.pulseRate = pulseRate
    self.date = date
    self.units = units
    self.type = type
  }
}
