import Foundation

public struct LocalBloodPressureSample: Equatable, Hashable, Encodable {
  public let systolic: LocalQuantitySample
  public let diastolic: LocalQuantitySample
  public let pulse: LocalQuantitySample?
  
  public init(
    systolic: LocalQuantitySample,
    diastolic: LocalQuantitySample,
    pulse: LocalQuantitySample?
  ) {
    self.systolic = systolic
    self.diastolic = diastolic
    self.pulse = pulse
  }
}
