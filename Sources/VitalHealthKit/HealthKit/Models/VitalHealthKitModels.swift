import HealthKit

struct DiscreteQuantity: Encodable {
  let id: String
  let value: Double
  let date: Date
  let sourceBundle: String
  
  init?(
    _ sample: HKSample,
    unit: Unit
  ) {
    guard let value = sample as? HKDiscreteQuantitySample else {
      return nil
    }
    
    self.id = value.uuid.uuidString
    self.value = value.quantity.doubleValue(for: unit.toHealthKit)
    self.date = value.startDate
    self.sourceBundle = value.sourceRevision.source.bundleIdentifier
  }
}

extension DiscreteQuantity {
  enum Unit {
    case height
    case bodyMass
    case bodyFatPercentage
    case heartRate
    case heartRateVariability
    
    var toHealthKit: HKUnit {
      switch self {
        case .heartRate:
          return .count().unitDivided(by: .minute())
        case .bodyMass:
          return .gramUnit(with: .kilo)
        case .bodyFatPercentage:
          return .percent()
        case .height:
          return .meterUnit(with: .centi)
        case .heartRateVariability:
          return .secondUnit(with: .milli)
      }
    }
  }
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
    let startDate: Date
    let endDate: Date
    let sourceBundle: String
    
    var heartRate: [DiscreteQuantity] = []
    var heartRateVariability: [DiscreteQuantity] = []

    init?(sample: HKSample) {
      guard let value = sample as? HKCategorySample else {
        return nil
      }
      
      self.id = value.uuid.uuidString
      self.startDate = value.startDate
      self.endDate = value.endDate
      self.sourceBundle = value.sourceRevision.source.bundleIdentifier
    }
  }
  
  let sleep: [Sleep]
}
