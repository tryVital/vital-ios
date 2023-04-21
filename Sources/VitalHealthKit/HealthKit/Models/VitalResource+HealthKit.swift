import HealthKit
import VitalCore

func remapResource(
  hasAskedForPermission: ((VitalResource) -> Bool),
  resource: VitalResource
) -> VitalResource {
  switch resource {
  case .individual(.bodyFat), .individual(.weight):
    /// If the user has explicitly asked for Body permissions, then it's the resource is Body
    if hasAskedForPermission(.body) {
      return .body
    } else {
      /// If the user has given permissions to a single permission in the past (e.g. weight) we should
      /// treat it as such
      return resource
    }

  case
      .individual(.steps), .individual(.activeEnergyBurned), .individual(.basalEnergyBurned),
      .individual(.distanceWalkingRunning), .individual(.floorsClimbed), .individual(.vo2Max):

      if hasAskedForPermission(.activity) {
        return .activity
      } else {
        return resource
      }

  case .activity, .body, .profile, .workout, .sleep, .vitals, .nutrition:
      return resource
  }
}

func toHealthKitTypes(individualResource: VitalResource.Individual) -> HKSampleType {
  switch individualResource {
  case .steps:
    return HKSampleType.quantityType(forIdentifier: .stepCount)!
  case .activeEnergyBurned:
    return HKSampleType.quantityType(forIdentifier: .activeEnergyBurned)!
  case .basalEnergyBurned:
    return HKSampleType.quantityType(forIdentifier: .basalEnergyBurned)!
  case .floorsClimbed:
    return HKSampleType.quantityType(forIdentifier: .flightsClimbed)!
  case .distanceWalkingRunning:
    return HKSampleType.quantityType(forIdentifier: .distanceWalkingRunning)!
  case .vo2Max:
    return HKSampleType.quantityType(forIdentifier: .vo2Max)!
  case .weight:
    return HKSampleType.quantityType(forIdentifier: .bodyMass)!
  case .bodyFat:
    return HKSampleType.quantityType(forIdentifier: .bodyFatPercentage)!
  }
}

func toHealthKitTypes(resource: VitalResource) -> Set<HKObjectType> {
  switch resource {
    case let .individual(resource):
      return [toHealthKitTypes(individualResource: resource)]
      
    case .profile:
      return [
        HKCharacteristicType.characteristicType(forIdentifier: .biologicalSex)!,
        HKCharacteristicType.characteristicType(forIdentifier: .dateOfBirth)!,
        HKQuantityType.quantityType(forIdentifier: .height)!,
      ]

    case .body:
      
      return toHealthKitTypes(resource: .individual(.bodyFat)) +
      toHealthKitTypes(resource: .individual(.weight))
      
    case .sleep:
      let temperature: Set<HKObjectType>
      if #available(iOS 16.0, *) {
        temperature = [HKSampleType.quantityType(forIdentifier: .appleSleepingWristTemperature)!]
      } else {
        temperature = []
      }

      return [
        HKSampleType.categoryType(forIdentifier: .sleepAnalysis)!,
        HKSampleType.quantityType(forIdentifier: .heartRate)!,
        HKSampleType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!,
        HKSampleType.quantityType(forIdentifier: .oxygenSaturation)!,
        HKSampleType.quantityType(forIdentifier: .restingHeartRate)!, 
        HKSampleType.quantityType(forIdentifier: .respiratoryRate)!,
      ] + temperature
      
    case .activity:
      return toHealthKitTypes(resource: .individual(.steps)) +
      toHealthKitTypes(resource: .individual(.floorsClimbed)) +
      toHealthKitTypes(resource: .individual(.basalEnergyBurned)) +
      toHealthKitTypes(resource: .individual(.activeEnergyBurned)) +
      toHealthKitTypes(resource: .individual(.distanceWalkingRunning)) +
      toHealthKitTypes(resource: .individual(.vo2Max))
      
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
      
    case .vitals(.hearthRate):
      return [
        HKSampleType.quantityType(forIdentifier: .heartRate)!
      ]
      
    case .nutrition(.water):
      return [
        .quantityType(forIdentifier: .dietaryWater)!
      ]

    case .nutrition(.caffeine):
      return [
        .quantityType(forIdentifier: .dietaryCaffeine)!
      ]

    case .vitals(.mindfulSession):
      return [
        .categoryType(forIdentifier: .mindfulSession)!
      ]

    case .vitals(.heartRateVariability):
      return [
        .quantityType(forIdentifier: .heartRateVariabilitySDNN)!
      ]
  }
}

/// This determines what data type change TRIGGERS a sync of the given `VitalResource`.
///
/// Not all types used in calculating a VitalResource have to be included here. Include only the
/// primary "container"/session data type here.
///
/// For example, a workout session might embed heart rate and respiratory rate samples. But we
/// need not require any insertion of these types to trigger HKWorkout sync, since generally speaking
/// all the relevant HR/RR samples during the session would have already been written before the
/// HKWorkout is eventually finalized and written. So we can simply fetch these samples w/o requiring
/// observation to drive it.
func sampleTypesToTriggerSync(for resource: VitalResource) -> Set<HKSampleType> {
  switch resource {
  case .individual(.steps):
    return [HKSampleType.quantityType(forIdentifier: .stepCount)!]

  case .individual(.activeEnergyBurned):
    return [HKSampleType.quantityType(forIdentifier: .activeEnergyBurned)!]

  case .individual(.basalEnergyBurned):
    return [HKSampleType.quantityType(forIdentifier: .basalEnergyBurned)!]

  case .individual(.floorsClimbed):
    return [HKSampleType.quantityType(forIdentifier: .flightsClimbed)!]

  case .individual(.distanceWalkingRunning):
    return [HKSampleType.quantityType(forIdentifier: .distanceWalkingRunning)!]

  case .individual(.vo2Max):
    return [HKSampleType.quantityType(forIdentifier: .vo2Max)!]

  case .individual(.weight):
    return [HKSampleType.quantityType(forIdentifier: .bodyMass)!]

  case .individual(.bodyFat):
    return [HKSampleType.quantityType(forIdentifier: .bodyFatPercentage)!]

  case .profile:
    return [HKQuantityType.quantityType(forIdentifier: .height)!]

  case .body:
    return sampleTypesToTriggerSync(for: .individual(.bodyFat)) +
    sampleTypesToTriggerSync(for: .individual(.weight))

  case .sleep:
    return [HKSampleType.categoryType(forIdentifier: .sleepAnalysis)!]

  case .activity:
    return sampleTypesToTriggerSync(for: .individual(.steps)) +
    sampleTypesToTriggerSync(for: .individual(.floorsClimbed)) +
    sampleTypesToTriggerSync(for: .individual(.basalEnergyBurned)) +
    sampleTypesToTriggerSync(for: .individual(.activeEnergyBurned)) +
    sampleTypesToTriggerSync(for: .individual(.distanceWalkingRunning)) +
    sampleTypesToTriggerSync(for: .individual(.vo2Max))

  case .workout:
    return [HKSampleType.workoutType()]

  case .vitals(.glucose):
    return [HKSampleType.quantityType(forIdentifier: .bloodGlucose)!]

  case .vitals(.bloodPressure):
    return [
      HKSampleType.quantityType(forIdentifier: .bloodPressureSystolic)!,
      HKSampleType.quantityType(forIdentifier: .bloodPressureDiastolic)!
    ]

  case .vitals(.hearthRate):
    return [HKSampleType.quantityType(forIdentifier: .heartRate)!]

  case .nutrition(.water):
    return [.quantityType(forIdentifier: .dietaryWater)!]

  case .nutrition(.caffeine):
    return [.quantityType(forIdentifier: .dietaryCaffeine)!]

  case .vitals(.mindfulSession):
    return [.categoryType(forIdentifier: .mindfulSession)!]

  case .vitals(.heartRateVariability):
    return [.quantityType(forIdentifier: .heartRateVariabilitySDNN)!]
  }
}
