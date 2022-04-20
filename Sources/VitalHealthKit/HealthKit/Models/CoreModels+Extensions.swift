import HealthKit
import VitalCore

extension BloodPressureSample {
  init?(
    _ sample: HKSample
  ) {
    
    func testType(_ identifier: HKQuantityTypeIdentifier) -> (HKSample) -> Bool {
      return { sample in
        guard
          let value = sample as? HKQuantitySample,
          value.quantityType == HKQuantityType.quantityType(forIdentifier: identifier)
        else {
          return false
        }
        
        return true
      }
    }
    
    guard
      let correlation = sample as? HKCorrelation,
      correlation.objects.count == 2,
      let diastolic = correlation.objects.first(where: testType(.bloodPressureDiastolic)),
      let systolic = correlation.objects.first(where: testType(.bloodPressureSystolic)),
      let diastolicSample = QuantitySample(diastolic, unit: .bloodPressure),
      let systolicSample = QuantitySample(systolic, unit: .bloodPressure)
    else {
      return nil
    }
        
    self.init(
      systolic: systolicSample,
      diastolic: diastolicSample,
      pulse: nil
    )
  }
}

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
      sourceBundle: value.sourceRevision.source.bundleIdentifier,
      type: "manual",
      unit: unit.toStringRepresentation
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
    
    case bloodPressure
    
    var toStringRepresentation: String {
      switch self {
        case .bodyMass:
          return "kg"
        case .bodyFatPercentage:
          return "percent"
        case .height:
          return "cm"
        case .heartRate:
          return "bpm"
        case .respiratoryRate:
          //  "breaths per minute"
          return "bpm"
        case .heartRateVariability:
          return "rmssd"
        case .oxygenSaturation:
          return "percent"
        case .restingHeartRate:
          return "bpm"
        case .basalEnergyBurned:
          return "kJ"
        case .steps:
          return ""
        case .floorsClimbed:
          return ""
        case .distanceWalkingRunning:
          return "m"
        case .vo2Max:
          return "mL/kg/min)"
        case .glucose:
          return "mmol/L"
          
        case .bloodPressure:
          return "mmHg"
      }
    }
    
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
          
        case .bloodPressure:
          return .millimeterOfMercury()
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
