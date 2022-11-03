import Foundation

public struct BloodPressureDataPoint: Equatable, Decodable, Hashable {
  public let id: Int?
  public let timestamp: Date
  
  public let systolic: Float
  public let diastolic: Float
  
  public let type: String?
  public let unit: String
}
