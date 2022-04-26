import Foundation

public struct BloodPressureSample: Equatable, Hashable, Encodable {
  public let systolic: QuantitySample
  public let diastolic: QuantitySample
  public let pulse: QuantitySample?
  
  public init(
    systolic: QuantitySample,
    diastolic: QuantitySample,
    pulse: QuantitySample?
  ) {
    self.systolic = systolic
    self.diastolic = diastolic
    self.pulse = pulse
  }
}
