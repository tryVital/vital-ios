import HealthKit

struct QuantitySample: Encodable {
  let id: UUID
  let value: Double
  let startDate: Date
  let endDate: Date
  let sourceBundle: String
  
  init?(
    _ sample: HKSample,
    unit: Unit
  ) {
    guard let value = sample as? HKQuantitySample else {
      return nil
    }
    
    self.id = value.uuid
    self.value = value.quantity.doubleValue(for: unit.toHealthKit)
    self.startDate = value.startDate
    self.endDate = value.endDate
    self.sourceBundle = value.sourceRevision.source.bundleIdentifier
  }
}

extension QuantitySample {
  enum Unit {
    case height
    case bodyMass
    case bodyFatPercentage
    case heartRate
    case heartRateVariability
    case restingHeartRate
    case oxygenSaturation
    case respiratoryRate
    
    case basalEnergyBurned
    case steps
    case floorsClimbed
    case distanceWalkingRunning
    case vo2Max
    
    case glucose
    
    var toHealthKit: HKUnit {
      switch self {
        case .heartRate:
          return .count().unitDivided(by: .minute())
        case .bodyMass:
          return .gram()
        case .bodyFatPercentage:
          return .percent()
        case .height:
          return .meterUnit(with: .centi)
          
        case .heartRateVariability:
          return .secondUnit(with: .milli)
        case .restingHeartRate:
          return .count().unitDivided(by: .minute())
        case .respiratoryRate:
          return .count().unitDivided(by: .minute())
        case .oxygenSaturation:
          return .percent()
          
        case .basalEnergyBurned:
          return .kilocalorie()
        case .steps:
          return .count()
        case .floorsClimbed:
          return .count()
        case .distanceWalkingRunning:
          return .meter()
        case .vo2Max:
          // ml/(kg*min)
          return .literUnit(with: .milli).unitDivided(by: .gramUnit(with: .kilo).unitMultiplied(by: .minute()))
        
        case .glucose:
          //  mmol/L
          return .moleUnit(with: .milli, molarMass: HKUnitMolarMassBloodGlucose).unitDivided(by: .liter())
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
  let height: Int?
}

struct VitalBodyPatch: Encodable {
  let bodyMass: [QuantitySample]
  let bodyFatPercentage: [QuantitySample]
}


struct VitalSleepPatch: Encodable {
  struct Sleep: Encodable {
    let id: UUID
    let startDate: Date
    let endDate: Date
    let sourceBundle: String
    
    var heartRate: [QuantitySample] = []
    var restingHeartRate: [QuantitySample] = []
    var heartRateVariability: [QuantitySample] = []
    var oxygenSaturation: [QuantitySample] = []
    var respiratoryRate: [QuantitySample] = []

    init?(sample: HKSample) {
      guard let value = sample as? HKCategorySample else {
        return nil
      }
      
      self.id = value.uuid
      self.startDate = value.startDate
      self.endDate = value.endDate
      self.sourceBundle = value.sourceRevision.source.bundleIdentifier
    }
  }
  
  let sleep: [Sleep]
}

struct VitalActivityPatch: Encodable {
  struct Activity: Encodable {
    let date: Date
    let activeEnergyBurned: Double
    let exerciseTime: Double
    let standingTime: Double
    let moveTime: Double
    
    var basalEnergyBurned: [QuantitySample] = []
    var steps: [QuantitySample] = []
    var floorsClimbed: [QuantitySample] = []
    var distanceWalkingRunning: [QuantitySample] = []
    var vo2Max: [QuantitySample] = []
    
    init?(activity: HKActivitySummary) {
      
      guard let date = activity.dateComponents(for: .current).date else {
        return nil
      }
      
      self.date = date
      
      self.activeEnergyBurned = activity.activeEnergyBurned.doubleValue(for: .kilocalorie())
      self.exerciseTime = activity.appleExerciseTime.doubleValue(for: .minute())
      self.standingTime = activity.appleStandHours.doubleValue(for: .count())
      self.moveTime = activity.appleMoveTime.doubleValue(for: .minute())
    }
  }
  
  let activities: [Activity]
}

struct VitalWorkoutPatch: Encodable {
  struct Workout: Encodable {
    let id: UUID
    let startDate: Date
    let endDate: Date
    let sourceBundle: String
    let sport: String
    let calories: Double
    let distance: Double

    var heartRate: [QuantitySample] = []
    var respiratoryRate: [QuantitySample] = []
    
    init?(sample: HKSample) {
      guard let workout = sample as? HKWorkout else {
        return nil
      }

      self.id = workout.uuid
      self.startDate = workout.startDate
      self.endDate = workout.endDate
      self.sport = workout.workoutActivityType.toString
      self.calories = workout.totalEnergyBurned?.doubleValue(for: .kilocalorie()) ?? 0
      self.distance = workout.totalDistance?.doubleValue(for: .meter()) ?? 0
      self.sourceBundle = workout.sourceRevision.source.bundleIdentifier
    }
  }
  
  let workouts: [Workout]
}

struct VitalGlucosePatch: Encodable {  
  let glucose: [QuantitySample]
}
