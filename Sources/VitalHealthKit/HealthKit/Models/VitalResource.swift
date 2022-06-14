import HealthKit
import VitalCore

func toHealthKitTypes(resource: VitalResource) -> Set<HKObjectType> {
  switch resource {
    case .profile:
      return [
        HKCharacteristicType.characteristicType(forIdentifier: .biologicalSex)!,
        HKCharacteristicType.characteristicType(forIdentifier: .dateOfBirth)!,
        HKQuantityType.quantityType(forIdentifier: .height)!,
      ]
      
    case .body:
      return [
        HKQuantityType.quantityType(forIdentifier: .bodyMass)!,
        HKQuantityType.quantityType(forIdentifier: .bodyFatPercentage)!,
      ]
      
    case .sleep:
      return [
        HKSampleType.categoryType(forIdentifier: .sleepAnalysis)!,
        HKSampleType.quantityType(forIdentifier: .heartRate)!,
        HKSampleType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!,
        HKSampleType.quantityType(forIdentifier: .oxygenSaturation)!,
        HKSampleType.quantityType(forIdentifier: .restingHeartRate)!, 
        HKSampleType.quantityType(forIdentifier: .respiratoryRate)!
      ]
      
    case .activity:
      return [
        HKSampleType.quantityType(forIdentifier: .stepCount)!,
        HKSampleType.quantityType(forIdentifier: .flightsClimbed)!,
        HKSampleType.quantityType(forIdentifier: .basalEnergyBurned)!,
        HKSampleType.quantityType(forIdentifier: .activeEnergyBurned)!,
        HKSampleType.quantityType(forIdentifier: .distanceWalkingRunning)!,
        HKSampleType.quantityType(forIdentifier: .vo2Max)!,
      ]
      
    case .workout:
      return [
        HKSampleType.workoutType(),
        HKSampleType.quantityType(forIdentifier: .heartRate)!,
        HKSampleType.quantityType(forIdentifier: .respiratoryRate)!
      ]
      
    case .vitals(.glucose):
      return [
        HKSampleType.quantityType(forIdentifier: .bloodGlucose)!
      ]
      
    case .vitals(.bloodPressure):
      return [
        HKSampleType.quantityType(forIdentifier: .bloodPressureSystolic)!,
        HKSampleType.quantityType(forIdentifier: .bloodPressureDiastolic)!
      ]
  }
}

func resource(forType type: HKSampleType) -> VitalResource {

  for resource in VitalResource.all {
    let types = toHealthKitTypes(resource: resource)
    
    if types.contains(type) {
      return resource
    }
  }
  
  fatalError("Type \(String.init(describing: type)), wasn't found. This seems like a developer error)")
}

func observedSampleTypes() -> [HKSampleType] {
  return [
    /// Profile
    HKQuantityType.quantityType(forIdentifier: .height)!,
    
    
    /// Body
    HKQuantityType.quantityType(forIdentifier: .bodyMass)!,
    HKQuantityType.quantityType(forIdentifier: .bodyFatPercentage)!,

    /// Sleep
    HKSampleType.categoryType(forIdentifier: .sleepAnalysis)!,

    /// Activity
    HKSampleType.quantityType(forIdentifier: .stepCount)!,
    HKSampleType.quantityType(forIdentifier: .flightsClimbed)!,
    HKSampleType.quantityType(forIdentifier: .basalEnergyBurned)!,
    HKSampleType.quantityType(forIdentifier: .activeEnergyBurned)!,
    HKSampleType.quantityType(forIdentifier: .distanceWalkingRunning)!,
    HKSampleType.quantityType(forIdentifier: .vo2Max)!,
    
    /// Workout
    HKSampleType.workoutType(),

    /// Vitals Glucose
    HKSampleType.quantityType(forIdentifier: .bloodGlucose)!,

    /// Vitals BloodPressure
    /// We only need to observe one, we know the other will be present. If we observe both,
    /// we are triggering the observer twice.
    //  HKSampleType.quantityType(forIdentifier: .bloodPressureSystolic)!,
    HKSampleType.quantityType(forIdentifier: .bloodPressureDiastolic)!
  ]
}

public func hasAskedForPermission(
  resource: VitalResource,
  store: HKHealthStore
) -> Bool {
  
  return toHealthKitTypes(resource: resource)
    .map { store.authorizationStatus(for: $0) != .notDetermined }
    .reduce(true, { $0 && $1})
}

func resourcesAskedForPermission(
  store: VitalHealthKitStore
) -> [VitalResource] {
  
  var resources: [VitalResource] = []
  
  for resource in VitalResource.all {
    guard toHealthKitTypes(resource: resource).isEmpty == false else {
      continue
    }
    
    let hasAskedPermission = store.hasAskedForPermission(resource)
    
    if hasAskedPermission {
      resources.append(resource)
    }
  }
  
  return resources
}
