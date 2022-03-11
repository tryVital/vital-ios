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
        HKSampleType.categoryType(forIdentifier: .sleepAnalysis)!
      ]
      
    default:
      return []
  }
}


func allTypesForBackgroundDelivery(
) -> [HKObjectType] {
  return Domain.all
    .flatMap(toHealthKitTypes(domain:))
    .filter { return $0.isKind(of: HKCharacteristicType.self) == false }
}

func domainsAskedForPermission(
  store: HKHealthStore
) -> [Domain] {
  
  var domains: [Domain] = []
  
  for domain in Domain.all {
    
    let hasAskedPermission = toHealthKitTypes(domain: domain)
      .map { store.authorizationStatus(for: $0) != .notDetermined }
      .reduce(true, { $0 && $1})
    
    if hasAskedPermission {
      domains.append(domain)
    }
  }
  
  
  return domains
}
