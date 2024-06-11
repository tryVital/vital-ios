import Foundation

public struct SleepResponse: Equatable, Decodable {
  public var sleep: [SleepSummary]
}

public struct SleepSummary: Equatable, Decodable {
  public var id: UUID
  public var source: Source
  public var calendarDate: String
  public var bedtimeStart: Date
  public var bedtimeStop: Date
  public var timezoneOffset: Int?
  public var duration: Int
  public var total: Int
  public var awake: Int
  public var light: Int
  public var rem: Int
  public var deep: Int
  public var score: Int?
  public var hrLowest: Int?
  public var hrAverage: Int?
  public var effiency: Int?
  public var latency: Int?
  public var temperatureDelta: Float?
  public var averageHrv: Float?
  public var respiratoryRate: Float?
}

public struct SleepRawResponse: Equatable, Decodable {
  public var sleep: [AnyDecodable]
}
