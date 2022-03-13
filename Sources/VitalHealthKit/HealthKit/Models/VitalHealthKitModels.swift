import HealthKit

struct DiscreteQuantity: Encodable {
  let id: String
  let value: Double
  let date: Date
  let sourceBundle: String
}

struct VitalProfilePatch: Encodable {
  enum BiologicalSex: String, Encodable {
    case male
    case female
    case other
    case notSet
    
    init(healthKitSex: HKBiologicalSex) {
      switch healthKitSex {
        case .notSet:
          self = .notSet
        case .female:
          self = .female
        case .male:
          self = .male
        case .other:
          self = .other
        @unknown default:
          self = .other
      }
    }
  }
  
  let biologicalSex: BiologicalSex?
  let dateOfBirth: Date?
}

struct VitalBodyPatch: Encodable {
  let height: [DiscreteQuantity]
  let bodyMass: [DiscreteQuantity]
  let bodyFatPercentage: [DiscreteQuantity]
}



struct VitalSleepPatch: Encodable {
  struct Sleep: Encodable {
    let id: String
    let startingDate: Date
    let endingDate: Date
    let sourceBundle: String
  }
  
  let sleep: [Sleep]
}
