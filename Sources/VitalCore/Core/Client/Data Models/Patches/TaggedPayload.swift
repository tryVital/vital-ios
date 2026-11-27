import Foundation

public struct TaggedPayload: Encodable {
  public let historicalPullId: UUID?
  public let recentPass: SDKRecentPass?
  public let stage: String
  public let startDate: Date?
  public let endDate: Date?
  public let timeZone: String
  public let provider: Provider.Slug
  public let data: VitalAnyEncodable
  public let isFinalChunk: Bool

  public init(
    stage: Stage = .daily,
    timeZone: TimeZone,
    provider: Provider.Slug = .manual,
    data: VitalAnyEncodable,
    isFinalChunk: Bool = true,
    historicalUpload: SDKHistoricalUpload? = nil
  ) {
    self.historicalPullId = historicalUpload?.historicalPullId
    self.recentPass = historicalUpload?.recentPass
    self.provider = provider
    self.data = data
    self.timeZone = timeZone.identifier
    self.isFinalChunk = isFinalChunk

    switch stage {
      case .daily:
        self.stage = "daily"
        self.startDate = nil
        self.endDate = nil
        
      case let .historical(start: startDate, end: endDate):
        self.stage = "historical"
        self.startDate = startDate
        self.endDate = endDate
    }
  }
}

public extension TaggedPayload {
  enum Stage: CustomStringConvertible {
    case daily
    case historical(start: Date, end: Date)
    
    public var isDaily: Bool {
      switch self {
        case .daily:
          return true
        case .historical:
          return false
      }
    }
    
    public var description: String {
      switch self {
        case .daily:
          return "daily"
        case let .historical(start: startDate, end: endDate):
          return "historical: \(startDate) - \(endDate)"
      }
    }
  }
}


public struct SDKRecentPass: Encodable {
  public let startDate: String
  public let endDate: String
  public let isLastBatch: Bool

  public init(startDate: String, endDate: String, isLastBatch: Bool) {
    self.startDate = startDate
    self.endDate = endDate
    self.isLastBatch = isLastBatch
  }
}

public struct SDKHistoricalUpload {
  public let historicalPullId: UUID
  public let recentPass: SDKRecentPass?

  public init(historicalPullId: UUID, recentPass: SDKRecentPass? = nil) {
    self.historicalPullId = historicalPullId
    self.recentPass = recentPass
  }
}
