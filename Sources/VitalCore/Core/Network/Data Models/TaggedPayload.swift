import Foundation

public struct TaggedPayload: Encodable {
  public let stage: Stage
  public let provider: String
  public let data: TaggedPayloadData
  
  public init(
    stage: Stage = .daily,
    provider: String = "manual",
    data: TaggedPayload.TaggedPayloadData
  ) {
    self.stage = stage
    self.provider = provider
    self.data = data
  }
}

public extension TaggedPayload {
  enum Stage: String, Encodable {
    case daily
    case historical
  }
  
  enum TaggedPayloadData: Encodable {
    public enum Vitals: Encodable {
      case glucose(GlucosePatch)
    }
    
    case profile(ProfilePatch)
    case activity(ActivityPatch)
    case workout(WorkoutPatch)
    case sleep(SleepPatch)
    case body(BodyPatch)
    case vitals(Vitals)
  }
}

