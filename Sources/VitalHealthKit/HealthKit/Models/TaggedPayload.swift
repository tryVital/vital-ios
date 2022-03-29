import Foundation

struct TaggedPayload: Encodable {
  let status: Status
  let stage: Stage
  let provider: String = "appleHealthKit"
  let providerId: String?
  let step: Int?
  let startDate: Date?
  let endDate: Date?
  let data: TaggedPayloadData
}


extension TaggedPayload {
  enum Status: String, Encodable {
    case inProgress
    case finished
  }
  
  enum Stage: String, Encodable {
    case daily
    case historical
  }
  
  enum TaggedPayloadData: Encodable {
    enum VitalData: Encodable {
      case glucose(VitalGlucosePatch)
    }
    
    case profile(VitalProfilePatch)
    case activity(VitalActivityPatch)
    case workout(VitalWorkoutPatch)
    case sleep(VitalSleepPatch)
    case body(VitalBodyPatch)
    case vital(VitalData)
  }
}
