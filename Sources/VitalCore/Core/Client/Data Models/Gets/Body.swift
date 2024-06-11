import Foundation

public struct BodyResponse: Equatable, Decodable {
  public var body: [BodySummary]
}

public struct BodyRawResponse: Equatable, Decodable {
  public var body: [AnyDecodable]
}

public struct BodySummary: Equatable, Decodable {
  public var id: UUID
  public var calendarDate: String
  public var weight: Double?
  public var fat: Double?
  public var source: Source
}
