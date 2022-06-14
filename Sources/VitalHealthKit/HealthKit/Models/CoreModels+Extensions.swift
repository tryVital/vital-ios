import HealthKit
import VitalCore

extension HKSampleType {
  
  var toVitalResource: VitalResource {
    
    switch self {
      case
        HKQuantityType.quantityType(forIdentifier: .bodyMass)!,
        HKQuantityType.quantityType(forIdentifier: .bodyFatPercentage)!:
        
        return .body
        
      case HKQuantityType.quantityType(forIdentifier: .height)!:
        return .profile
        
      case HKSampleType.workoutType():
        return .workout
        
      case HKSampleType.categoryType(forIdentifier: .sleepAnalysis):
        return .sleep
        
      case
        HKSampleType.quantityType(forIdentifier: .activeEnergyBurned)!,
        HKSampleType.quantityType(forIdentifier: .basalEnergyBurned)!,
        HKSampleType.quantityType(forIdentifier: .stepCount)!,
        HKSampleType.quantityType(forIdentifier: .flightsClimbed)!,
        HKSampleType.quantityType(forIdentifier: .distanceWalkingRunning)!,
        HKSampleType.quantityType(forIdentifier: .vo2Max)!:
        return .activity
        
      case HKSampleType.quantityType(forIdentifier: .bloodGlucose)!:
        return .vitals(.glucose)
        
      case
        HKSampleType.quantityType(forIdentifier: .bloodPressureSystolic)!,
        HKSampleType.quantityType(forIdentifier: .bloodPressureDiastolic)!:
        return .vitals(.bloodPressure)
        
      default:
        fatalError("\(String(describing: self)) type not supported)")
    }
  }
}

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
      let diastolicSample = QuantitySample(diastolic),
      let systolicSample = QuantitySample(systolic)
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
    _ sample: HKSample
  ) {
    guard let value = sample as? HKQuantitySample else {
      return nil
    }
    
    self.init(
      id: value.uuid.uuidString,
      value: value.quantity.doubleValue(for: sample.sampleType.toHealthKitUnits),
      startDate: value.startDate,
      endDate: value.endDate,
      sourceBundle: value.sourceRevision.source.bundleIdentifier,
      type: "manual",
      unit: sample.sampleType.toUnitStringRepresentation
    )
  }
}

extension HKSampleType {
  var toUnitStringRepresentation: String {
    switch self {
      case HKQuantityType.quantityType(forIdentifier: .bodyMass)!:
        return "kg"
      case HKQuantityType.quantityType(forIdentifier: .bodyFatPercentage)!:
        return "percent"
        
      case HKQuantityType.quantityType(forIdentifier: .height)!:
        return "cm"
        
      case HKSampleType.quantityType(forIdentifier: .heartRate)!:
        return "bpm"
      case HKSampleType.quantityType(forIdentifier: .respiratoryRate)!:
        //  "breaths per minute"
        return "bpm"
        
      case HKSampleType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!:
        return "rmssd"
      case HKSampleType.quantityType(forIdentifier: .oxygenSaturation)!:
        return "percent"
      case HKSampleType.quantityType(forIdentifier: .restingHeartRate)!:
        return "bpm"
      
      case
        HKSampleType.quantityType(forIdentifier: .activeEnergyBurned)!,
        HKSampleType.quantityType(forIdentifier: .basalEnergyBurned)!:
        return "kJ"
        
      case HKSampleType.quantityType(forIdentifier: .stepCount)!:
        return ""
      case HKSampleType.quantityType(forIdentifier: .flightsClimbed)!:
        return ""
      case HKSampleType.quantityType(forIdentifier: .distanceWalkingRunning)!:
        return "m"
      case  HKSampleType.quantityType(forIdentifier: .vo2Max)!:
        return "mL/kg/min"
        
      case HKSampleType.quantityType(forIdentifier: .bloodGlucose)!:
        return "mmol/L"
        
      case
        HKSampleType.quantityType(forIdentifier: .bloodPressureSystolic)!,
        HKSampleType.quantityType(forIdentifier: .bloodPressureDiastolic)!:
        return "mmHg"
        
      default:
        fatalError("\(String(describing: self)) type not supported)")
    }
  }
  
  var toHealthKitUnits: HKUnit {
    switch self {
      case HKQuantityType.quantityType(forIdentifier: .bodyMass)!:
        return .gramUnit(with: .kilo)
      case HKQuantityType.quantityType(forIdentifier: .bodyFatPercentage)!:
        return .percent()
        
      case HKQuantityType.quantityType(forIdentifier: .height)!:
        return .meterUnit(with: .centi)
        
      case HKSampleType.quantityType(forIdentifier: .heartRate)!:
        return .count().unitDivided(by: .minute())
      case HKSampleType.quantityType(forIdentifier: .respiratoryRate)!:
        //  "breaths per minute"
        return .count().unitDivided(by: .minute())
        
      case HKSampleType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!:
        return .secondUnit(with: .milli)
      case HKSampleType.quantityType(forIdentifier: .oxygenSaturation)!:
        return .percent()
      case HKSampleType.quantityType(forIdentifier: .restingHeartRate)!:
        return .count().unitDivided(by: .minute())
        
      case
        HKSampleType.quantityType(forIdentifier: .activeEnergyBurned)!,
        HKSampleType.quantityType(forIdentifier: .basalEnergyBurned)!:
        return .kilocalorie()
        
      case HKSampleType.quantityType(forIdentifier: .stepCount)!:
        return .count()
      case HKSampleType.quantityType(forIdentifier: .flightsClimbed)!:
        return .count()
      case HKSampleType.quantityType(forIdentifier: .distanceWalkingRunning)!:
        return .meter()
      case  HKSampleType.quantityType(forIdentifier: .vo2Max)!:
        return .literUnit(with: .milli).unitDivided(by: .gramUnit(with: .kilo).unitMultiplied(by: .minute()))
        
      case HKSampleType.quantityType(forIdentifier: .bloodGlucose)!:
        return .moleUnit(with: .milli, molarMass: HKUnitMolarMassBloodGlucose).unitDivided(by: .liter())
        
      case
        HKSampleType.quantityType(forIdentifier: .bloodPressureSystolic)!,
        HKSampleType.quantityType(forIdentifier: .bloodPressureDiastolic)!:
        return .millimeterOfMercury()
        
      default:
        fatalError("\(String(describing: self)) type not supported)")
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
