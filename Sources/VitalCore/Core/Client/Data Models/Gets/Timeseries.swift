import Foundation

public struct TimeseriesSummary: Equatable, Decodable {
  public var id: Int?
  public var timestamp: Date
  public var value: Float
  public var type: String?
  public var unit: String?
}
