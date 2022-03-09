import HealthKit

func toHealthKitTypes(permission: Permission) -> Set<HKObjectType> {
  switch permission {
    case .body:
      return [
        HKCharacteristicType.characteristicType(forIdentifier: .biologicalSex)!,
        HKCharacteristicType.characteristicType(forIdentifier: .dateOfBirth)!,
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
  return Permission.all
    .flatMap(toHealthKitTypes(permission:))
    .filter { return $0.isKind(of: HKCharacteristicType.self) == false }
}

func allTypesAskedForPermission(
  store: HKHealthStore
) -> [HKObjectType] {
   return Permission.all
    .flatMap(toHealthKitTypes(permission:))
    .filter { store.authorizationStatus(for: $0) != .notDetermined }
}
