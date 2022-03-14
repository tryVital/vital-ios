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
    case oxygenSaturation
    
    case basalEnergyBurned
    case steps
    case floorsClimbed
    case distanceWalkingRunning
    case vo2Max
    
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
        case .oxygenSaturation:
          return .percent()
          
        case .basalEnergyBurned:
          return .kilocalorie()
        case .steps:
          return .count()
        case .floorsClimbed:
          return .count()
        case .distanceWalkingRunning:
          return .meterUnit(with: .kilo)
        case .vo2Max:
          // ml/(kg*min)
          return .literUnit(with: .milli).unitDivided(by: .gramUnit(with: .kilo).unitMultiplied(by: .minute()))
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
    var oxygenSaturation: [DiscreteQuantity] = []

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

struct VitalActivityPatch: Encodable {
  struct Activity: Encodable {
    let date: Date?
    let activeEnergyBurned: Double
    let exerciseTime: Double
    let standingTime: Double
    let moveTime: Double
    
    var basalEnergyBurned: [DiscreteQuantity] = []
    var steps: [DiscreteQuantity] = []
    var floorsClimbed: [DiscreteQuantity] = []
    var distanceWalkingRunning: [DiscreteQuantity] = []
    var vo2Max: [DiscreteQuantity] = []
    
    init(activity: HKActivitySummary) {
      
      self.date = activity.dateComponents(for: .current).date
      
      self.activeEnergyBurned = activity.activeEnergyBurned.doubleValue(for: .kilocalorie())
      self.exerciseTime = activity.appleExerciseTime.doubleValue(for: .minute())
      self.standingTime = activity.appleStandHours.doubleValue(for: .count())
      self.moveTime = activity.appleMoveTime.doubleValue(for: .minute())
    }
  }
  
  let activities: [Activity]
}
