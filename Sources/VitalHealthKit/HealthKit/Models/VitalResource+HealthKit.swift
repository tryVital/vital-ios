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

func toHealthKitTypes(resource: VitalResource) -> Set<HKObjectType> {
  switch resource {
    case .individual(.steps):
      return [
        HKSampleType.quantityType(forIdentifier: .stepCount)!,
      ]
    case .individual(.activeEnergyBurned):
      return [
        HKSampleType.quantityType(forIdentifier: .activeEnergyBurned)!,
      ]
    case .individual(.basalEnergyBurned):
      return [
        HKSampleType.quantityType(forIdentifier: .basalEnergyBurned)!,
      ]
    case .individual(.floorsClimbed):
      return [
        HKSampleType.quantityType(forIdentifier: .flightsClimbed)!,
      ]
    case .individual(.distanceWalkingRunning):
      return [
        HKSampleType.quantityType(forIdentifier: .distanceWalkingRunning)!,
      ]
    case .individual(.vo2Max):
      return [
        HKSampleType.quantityType(forIdentifier: .vo2Max)!,
      ]
    case .individual(.weight):
      return [
        HKSampleType.quantityType(forIdentifier: .bodyMass)!,
      ]
    case .individual(.bodyFat):
      return [
        HKSampleType.quantityType(forIdentifier: .bodyFatPercentage)!,
      ]
      
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

func observedSampleTypes() -> [[HKSampleType]] {
  return [
    /// Profile
    [
      HKQuantityType.quantityType(forIdentifier: .height)!
    ],
    
    
    /// Body
    [
      HKQuantityType.quantityType(forIdentifier: .bodyMass)!,
      HKQuantityType.quantityType(forIdentifier: .bodyFatPercentage)!
    ],

    /// Sleep
    [
      HKSampleType.categoryType(forIdentifier: .sleepAnalysis)!]
    ,

    /// Activity
    [
      HKSampleType.quantityType(forIdentifier: .stepCount)!,
      HKSampleType.quantityType(forIdentifier: .flightsClimbed)!,
      HKSampleType.quantityType(forIdentifier: .basalEnergyBurned)!,
      HKSampleType.quantityType(forIdentifier: .activeEnergyBurned)!,
      HKSampleType.quantityType(forIdentifier: .distanceWalkingRunning)!,
      HKSampleType.quantityType(forIdentifier: .vo2Max)!
    ],
    
    /// Workout
    [
      HKSampleType.workoutType()
    ],

    /// Vitals Glucose
    [
      HKSampleType.quantityType(forIdentifier: .bloodGlucose)!
    ],

    /// Mindfuless Minutes
    [
      HKSampleType.categoryType(forIdentifier: .mindfulSession)!
    ],

    /// Vitals BloodPressure
    /// We only need to observe one, we know the other will be present. If we observe both,
    /// we are triggering the observer twice.
    //  HKSampleType.quantityType(forIdentifier: .bloodPressureSystolic)!,
    [
      HKSampleType.quantityType(forIdentifier: .bloodPressureDiastolic)!
    ],
    
    /// Vitals Heartrate
    [
      HKSampleType.quantityType(forIdentifier: .heartRate)!,
    ],

    /// Vitals HRV
    [
      HKSampleType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!
    ],
    
    /// Nutrition
    [
      HKSampleType.quantityType(forIdentifier: .dietaryWater)!,
      HKSampleType.quantityType(forIdentifier: .dietaryCaffeine)!
    ],

    /// Mindfulness Minutes
    [
      HKSampleType.categoryType(forIdentifier: .mindfulSession)!
    ]
  ]
}
