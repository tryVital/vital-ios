import Foundation

public struct ActivityResponse: Equatable, Decodable {
  public var activity: [ActivitySummary]
}

public struct ActivityRawResponse: Equatable, Decodable {
  public var activity: [AnyDecodable]
}

public struct ActivitySummary: Equatable, Decodable {
  public var id: UUID
  public var date: Date
  public var caloriesTotal: Double?
  public var caloriesActive: Double?
  public var steps: Int?
  public var dailyMovement: Int?
  public var low: Double?
  public var medium: Double?
  public var high: Double?
  public var source: SourceSummary
  public var floorsClimbed: Int?
  public var timezoneOffset: Int?
}
