import HealthKit

func toHealthKitTypes(domain: Domain) -> Set<HKObjectType> {
  switch domain {
    case .profile:
      return [
        HKCharacteristicType.characteristicType(forIdentifier: .biologicalSex)!,
        HKCharacteristicType.characteristicType(forIdentifier: .dateOfBirth)!,
      ]
      
    case .body:
      return [
        HKQuantityType.quantityType(forIdentifier: .height)!,
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
        HKSampleType.quantityType(forIdentifier: .distanceWalkingRunning)!,
        HKSampleType.quantityType(forIdentifier: .vo2Max)!,
      ]
      
    case .workout:
      return [
        HKSampleType.workoutType(),
        HKSampleType.quantityType(forIdentifier: .heartRate)!,
        HKSampleType.quantityType(forIdentifier: .respiratoryRate)!
      ]
      
    default:
      return []
  }
}


func allTypesForBackgroundDelivery(
) -> [HKObjectType] {
  return Domain.all
    .flatMap(toHealthKitTypes(domain:))
    .filter {
      return $0.isKind(of: HKCharacteristicType.self) == false
          && $0.isKind(of: HKActivitySummaryType.self) == false
    }
}

func domainsAskedForPermission(
  store: HKHealthStore
) -> [Domain] {
  
  var domains: [Domain] = []
  
  for domain in Domain.all {
    guard toHealthKitTypes(domain: domain).isEmpty == false else {
      continue
    }
    
    let hasAskedPermission = toHealthKitTypes(domain: domain)
      .map { store.authorizationStatus(for: $0) != .notDetermined }
      .reduce(true, { $0 && $1})
    
    if hasAskedPermission {
      domains.append(domain)
    }
  }
  
  return domains
}
