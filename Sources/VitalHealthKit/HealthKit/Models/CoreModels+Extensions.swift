import HealthKit
import VitalCore

extension QuantitySample {
  init?(
    _ sample: HKSample,
    unit: Unit
  ) {
    guard let value = sample as? HKQuantitySample else {
      return nil
    }
    
    self.init(
      id: value.uuid,
      value: value.quantity.doubleValue(for: unit.toHealthKit),
      startDate: value.startDate,
      endDate: value.endDate,
      sourceBundle: value.sourceRevision.source.bundleIdentifier
    )
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

extension ProfilePatch.BiologicalSex {
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

public extension SleepPatch.Sleep {
  init?(sample: HKSample) {
    guard let value = sample as? HKCategorySample else {
      return nil
    }
    
    self.init(
      id: value.uuid,
      startDate: value.startDate,
      endDate: value.endDate,
      sourceBundle: value.sourceRevision.source.bundleIdentifier
    )
  }
}

extension ActivityPatch.Activity {
  public init?(activity: HKActivitySummary) {
    
    guard let date = activity.dateComponents(for: .current).date else {
      return nil
    }
    
    self.init(
      date: date,
      activeEnergyBurned: activity.activeEnergyBurned.doubleValue(for: .kilocalorie()),
      exerciseTime: activity.appleExerciseTime.doubleValue(for: .minute()),
      standingTime: activity.appleStandHours.doubleValue(for: .count()),
      moveTime: activity.appleMoveTime.doubleValue(for: .minute())
    )
  }
}

extension WorkoutPatch.Workout {
  public init?(sample: HKSample) {
    guard let workout = sample as? HKWorkout else {
      return nil
    }
    
    self.init(
      id: workout.uuid,
      startDate: workout.startDate,
      endDate: workout.endDate,
      sourceBundle: workout.sourceRevision.source.bundleIdentifier,
      sport: workout.workoutActivityType.toString,
      calories: workout.totalEnergyBurned?.doubleValue(for: .kilocalorie()) ?? 0,
      distance: workout.totalDistance?.doubleValue(for: .meter()) ?? 0
    )
  }
}
