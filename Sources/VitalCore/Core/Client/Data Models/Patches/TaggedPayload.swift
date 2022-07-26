import Foundation

public struct TaggedPayload: Encodable {
  public let stage: String
  public let startDate: Date?
  public let endDate: Date?
  public let provider: Provider
  public let data: VitalAnyEncodable
  
  public init(
    stage: Stage = .daily,
    provider: Provider = .manual,
    data: VitalAnyEncodable
  ) {
    self.provider = provider
    self.data = data
    
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
  enum Stage {
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
  }
  
  enum Data: Encodable {
    public enum Vitals: Encodable {
      case glucose([QuantitySample])
    }
    
    case profile(ProfilePatch)
    case activity(ActivityPatch)
    case workout(WorkoutPatch)
    case sleep(SleepPatch)
    case body(BodyPatch)
    case vitals(Vitals)
  }
}

