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
        HKSampleType.activitySummaryType(),
        HKSampleType.quantityType(forIdentifier: .stepCount)!,
        HKSampleType.quantityType(forIdentifier: .flightsClimbed)!,
        HKSampleType.quantityType(forIdentifier: .basalEnergyBurned)!,
        HKSampleType.quantityType(forIdentifier: .activeEnergyBurned)!,
        HKSampleType.categoryType(forIdentifier: .appleStandHour)!,
        HKSampleType.quantityType(forIdentifier: .appleExerciseTime)!,
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

func observedSamples(resource: VitalResource) -> [HKSampleType] {
  toHealthKitTypes(resource: resource).compactMap {
    return $0 as? HKSampleType
  }
}

//func allTypesForBackgroundDelivery(
//) -> [HKObjectType] {
//  return VitalResource.all
//    .flatMap(toHealthKitTypes(resource:))
//    .filter {
//      return $0.isKind(of: HKCharacteristicType.self) == false
//          && $0.isKind(of: HKActivitySummaryType.self) == false
//    }
//}

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
