import HealthKit
import VitalCore

struct HealthKitObjectTypeRequirements {
  /// The required set of HKObjectTypes of a `VitalResource`.
  ///
  /// This must not change once the `VitalResource` is introduced, especially if
  /// the `VitalResource` is a fully computed resource like `activity`.
  let required: Set<HKObjectType>

  /// An optional set of HKObjectTypes of a `VitalResource`.
  /// New types can be added or removed from this list.
  let optional: Set<HKObjectType>

  var isIndividualType: Bool {
    required.count == 1 && optional.isEmpty
  }

  func isResourceActive(_ query: (HKObjectType) -> Bool) -> Bool {
    return self.required.allSatisfy(query) && (
      self.optional.isEmpty || self.optional.contains(where: query)
    )
  }
}

private func single(_ type: HKObjectType) -> HealthKitObjectTypeRequirements {
  return HealthKitObjectTypeRequirements(required: [type], optional: [])
}

func toHealthKitTypes(resource: VitalResource) -> HealthKitObjectTypeRequirements {
  switch resource {
  case .individual(.steps):
    return single(HKSampleType.quantityType(forIdentifier: .stepCount)!)
  case .individual(.activeEnergyBurned):
    return single(HKSampleType.quantityType(forIdentifier: .activeEnergyBurned)!)
  case .individual(.basalEnergyBurned):
    return single(HKSampleType.quantityType(forIdentifier: .basalEnergyBurned)!)
  case .individual(.floorsClimbed):
    return single(HKSampleType.quantityType(forIdentifier: .flightsClimbed)!)
  case .individual(.distanceWalkingRunning):
    return single(HKSampleType.quantityType(forIdentifier: .distanceWalkingRunning)!)
  case .individual(.vo2Max):
    return single(HKSampleType.quantityType(forIdentifier: .vo2Max)!)
  case .individual(.exerciseTime):
    return single(HKSampleType.quantityType(forIdentifier: .appleExerciseTime)!)
  case .individual(.weight):
    return single(HKSampleType.quantityType(forIdentifier: .bodyMass)!)
  case .individual(.bodyFat):
    return single(HKSampleType.quantityType(forIdentifier: .bodyFatPercentage)!)
  case .vitals(.bloodOxygen):
    return single(HKSampleType.quantityType(forIdentifier: .oxygenSaturation)!)

  case .profile:
    return HealthKitObjectTypeRequirements(
      required: [],
      optional: [
        HKCharacteristicType.characteristicType(forIdentifier: .biologicalSex)!,
        HKCharacteristicType.characteristicType(forIdentifier: .dateOfBirth)!,
        HKQuantityType.quantityType(forIdentifier: .height)!,
      ]
    )

  case .body:
    return HealthKitObjectTypeRequirements(required: [], optional: [
      HKSampleType.quantityType(forIdentifier: .bodyFatPercentage)!,
      HKSampleType.quantityType(forIdentifier: .bodyMass)!,
    ])

  case .sleep:
    let temperature: Set<HKObjectType>
    if #available(iOS 16.0, *) {
      temperature = [HKSampleType.quantityType(forIdentifier: .appleSleepingWristTemperature)!]
    } else {
      temperature = []
    }

    return HealthKitObjectTypeRequirements(
      required: [
        HKSampleType.categoryType(forIdentifier: .sleepAnalysis)!,
      ],
      optional: [
        HKSampleType.quantityType(forIdentifier: .heartRate)!,
        HKSampleType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!,
        HKSampleType.quantityType(forIdentifier: .oxygenSaturation)!,
        HKSampleType.quantityType(forIdentifier: .restingHeartRate)!,
        HKSampleType.quantityType(forIdentifier: .respiratoryRate)!,
      ] + temperature
    )

  case .activity:

    return HealthKitObjectTypeRequirements(
      required: [], optional: [
        HKSampleType.quantityType(forIdentifier: .stepCount)!,
        HKSampleType.quantityType(forIdentifier: .basalEnergyBurned)!,
        HKSampleType.quantityType(forIdentifier: .activeEnergyBurned)!,
        HKSampleType.quantityType(forIdentifier: .flightsClimbed)!,
        HKSampleType.quantityType(forIdentifier: .distanceWalkingRunning)!,
        HKSampleType.quantityType(forIdentifier: .vo2Max)!,
        HKSampleType.quantityType(forIdentifier: .heartRate)!,
        HKSampleType.quantityType(forIdentifier: .restingHeartRate)!,
        HKSampleType.quantityType(forIdentifier: .appleExerciseTime)!
      ]
    )

  case .workout:
    return HealthKitObjectTypeRequirements(
      required: [HKSampleType.workoutType()],
      optional: [
        HKSampleType.quantityType(forIdentifier: .heartRate)!,
        HKSampleType.quantityType(forIdentifier: .respiratoryRate)!
      ]
    )

  case .vitals(.glucose):
    return single(HKSampleType.quantityType(forIdentifier: .bloodGlucose)!)

  case .vitals(.bloodPressure):
    return HealthKitObjectTypeRequirements(
      required: [
        HKSampleType.quantityType(forIdentifier: .bloodPressureSystolic)!,
        HKSampleType.quantityType(forIdentifier: .bloodPressureDiastolic)!,
      ],
      optional: []
    )

  case .vitals(.heartRate):
    return single(HKSampleType.quantityType(forIdentifier: .heartRate)!)

  case .nutrition(.water):
    return single(.quantityType(forIdentifier: .dietaryWater)!)

  case .nutrition(.caffeine):
    return single(.quantityType(forIdentifier: .dietaryCaffeine)!)

  case .vitals(.mindfulSession):
    return single(.categoryType(forIdentifier: .mindfulSession)!)

  case .vitals(.heartRateVariability):
    return single(.quantityType(forIdentifier: .heartRateVariabilitySDNN)!)
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
      HKSampleType.quantityType(forIdentifier: .vo2Max)!,
      HKSampleType.quantityType(forIdentifier: .appleExerciseTime)!
    ],
    
    /// Workout
    [
      HKSampleType.workoutType()
    ],

    /// Vitals Glucose
    [
      HKSampleType.quantityType(forIdentifier: .bloodGlucose)!
    ],

    /// Vitals Blood Oxygen
    [
      HKSampleType.quantityType(forIdentifier: .oxygenSaturation)!
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

func resourcesAskedForPermission(
  store: VitalHealthKitStore
) -> [VitalResource] {
  
  var resources: [VitalResource] = []
  
  for resource in VitalResource.all {
    let requirements = toHealthKitTypes(resource: resource)
    
    let hasAskedPermission = store.hasAskedForPermission(resource)
    
    if hasAskedPermission {
      resources.append(resource)
    }
  }
  
  return resources
}
