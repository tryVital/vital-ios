import Foundation

public struct WorkoutResponse: Equatable, Decodable {
  public var workouts: [WorkoutSummary]
}

public struct WorkoutSummary: Equatable, Decodable {
  public var id: UUID
  public var providerId: String
  public var title: String?
  public var timezoneOffset: Int?

  public var averageHr: Int?
  public var maxHr: Int?
  public var distance: Double?
  public var timeStart: Date
  public var timeEnd: Date
  public var calories: Double?
  public var sport: Sport
  public var hrZones: [Int]?
  public var movingTime: Int?
  public var totalElevationGain: Int?
  public var elevHigh: Double?
  public var elevLow: Double?
  public var averageSpeed: Double?
  public var maxSpeed: Double?
  public var averageWatts: Double?
  public var deviceWatts: Double?
  public var maxWatts: Double?
  public var weightedAverageWatts: Double?
  public var map: AnyDecodable
  public var dailyMovement: Int?
  public var low: Double?
  public var medium: Double?
  public var high: Double?
  public var source: SourceSummary
  public var floorsClimbed: Int?
}

public struct Sport: Equatable, Decodable {
  public var id: Int
  public var name: String
  public var slug: String
}


public struct WorkoutRawResponse: Equatable, Decodable {
  public var workouts: [AnyDecodable]
}
