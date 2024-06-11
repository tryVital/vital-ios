import Foundation

public struct BloodPressureSample: Equatable, Decodable, Hashable {
  public let timestamp: Date
  
  public let systolic: Float
  public let diastolic: Float
  
  public let type: String?
  public let unit: String

  public init(timestamp: Date, systolic: Float, diastolic: Float, type: String?, unit: String) {
    self.timestamp = timestamp
    self.systolic = systolic
    self.diastolic = diastolic
    self.type = type
    self.unit = unit
  }
}
