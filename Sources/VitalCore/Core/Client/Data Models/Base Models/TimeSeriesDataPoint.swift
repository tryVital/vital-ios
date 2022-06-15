import Foundation

public struct TimeSeriesDataPoint: Equatable, Decodable, Hashable {
  public let id: Int?
  public let timestamp: Date
  
  public let value: Float
  public let type: String?
  public let unit: String?
}
