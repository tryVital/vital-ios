import HealthKit
import VitalCore

/// Describes how HealthKit sample types map to a particular VitalResource.
///
/// ### `ask(_:)` behaviour:
/// We request `required` + `optional` + `supplementary`.
///
/// ### `hasAskedForPermission(_:)` behaviour:
/// If `required` is non-empty:
/// * A VitalResource is "asked" if and only if all `required` sample types have been asked.
/// If `required` is empty:
/// * A VitalResource is "asked" if at least one `optional` sample types have been asked.
/// In both cases, `supplementary` is not considered at all.
///
/// Some sample types may appear in multiple `VitalResource`s:
/// 1. Each sample type can only be associated with ** one** VitalResource as their `required` or `optional` types.
/// 2. A sample type can optionally be marked as a `supplementary` type of any other VitalResource.
///
/// Example:
/// * `VitalResource.heartrate` is the primary resource for `HKQuantityType(.heartRate)`.
/// * Activity, workouts and sleeps all need _supplementary_ heartrate permission for statistics, but can function without it.
///   So they list `HKQuantityType(.heartRate)` as their `supplementary` types.
struct HealthKitObjectTypeRequirements {
  /// The required set of HKObjectTypes of a `VitalResource`.
  ///
  /// This must not change once the `VitalResource` is introduced, especially if
  /// the `VitalResource` is a fully computed resource like `activity`.
  let required: Set<HKObjectType>

  /// An optional set of HKObjectTypes of a `VitalResource`.
  /// New types can be added or removed from this list.
  let optional: Set<HKObjectType>

  /// An "supplementary" set of HKObjectTypes of a `VitalResource`.
  /// New types can be added or removed from this list.
  let supplementary: Set<HKObjectType>

  var isIndividualType: Bool {
    required.count == 1 && optional.isEmpty && supplementary.isEmpty
  }

  func isResourceActive(_ query: (HKObjectType) -> Bool) -> Bool {
    if self.required.isEmpty {
      return self.optional.contains(where: query)
    } else {
      return self.required.allSatisfy(query)
    }
  }

  var allObjectTypes: Set<HKObjectType> {
    var objectTypes = self.required
    objectTypes.formUnion(self.optional)
    objectTypes.formUnion(self.supplementary)
    return objectTypes
  }
}

private func single(_ type: HKObjectType) -> HealthKitObjectTypeRequirements {
  return HealthKitObjectTypeRequirements(required: [type], optional: [], supplementary: [])
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
      ],
      supplementary: []
    )

  case .body:
    return HealthKitObjectTypeRequirements(required: [], optional: [
      HKSampleType.quantityType(forIdentifier: .bodyFatPercentage)!,
      HKSampleType.quantityType(forIdentifier: .bodyMass)!,
    ], supplementary: [])

  case .sleep:
    let wristTemperature: Set<HKObjectType>
    if #available(iOS 16.0, *) {
      wristTemperature = [HKSampleType.quantityType(forIdentifier: .appleSleepingWristTemperature)!]
    } else {
      wristTemperature = []
    }

    return HealthKitObjectTypeRequirements(
      required: [
        HKSampleType.categoryType(forIdentifier: .sleepAnalysis)!,
      ],
      optional: wristTemperature,
      supplementary: [
        HKSampleType.quantityType(forIdentifier: .respiratoryRate)!,
        HKSampleType.quantityType(forIdentifier: .restingHeartRate)!,
        HKSampleType.quantityType(forIdentifier: .heartRate)!,
        HKSampleType.quantityType(forIdentifier: .oxygenSaturation)!,
        HKSampleType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!,
      ]
    )

  case .activity:

    return HealthKitObjectTypeRequirements(
      required: [],
      optional: [
        HKSampleType.quantityType(forIdentifier: .stepCount)!,
        HKSampleType.quantityType(forIdentifier: .basalEnergyBurned)!,
        HKSampleType.quantityType(forIdentifier: .activeEnergyBurned)!,
        HKSampleType.quantityType(forIdentifier: .flightsClimbed)!,
        HKSampleType.quantityType(forIdentifier: .distanceWalkingRunning)!,
        HKSampleType.quantityType(forIdentifier: .vo2Max)!,
        HKSampleType.quantityType(forIdentifier: .appleExerciseTime)!
      ],
      supplementary: [
        HKSampleType.quantityType(forIdentifier: .heartRate)!,
        HKSampleType.quantityType(forIdentifier: .restingHeartRate)!,
      ]
    )

  case .workout:
    return HealthKitObjectTypeRequirements(
      required: [HKSampleType.workoutType()],
      optional: [
        HKSampleType.quantityType(forIdentifier: .respiratoryRate)!
      ],
      supplementary: [
        HKSampleType.quantityType(forIdentifier: .heartRate)!,
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
      optional: [],
      supplementary: []
    )

  case .menstrualCycle:
    var optionalTypes: Set<HKSampleType> = [
      HKCategoryType.categoryType(forIdentifier: .cervicalMucusQuality)!,
      HKCategoryType.categoryType(forIdentifier: .intermenstrualBleeding)!,
      HKCategoryType.categoryType(forIdentifier: .ovulationTestResult)!,
    ]

    let supplementaryTypes: Set<HKSampleType> = [
      HKCategoryType.categoryType(forIdentifier: .sexualActivity)!,
      HKQuantityType.quantityType(forIdentifier: .basalBodyTemperature)!,
    ]

    if #available(iOS 15.0, *) {
      optionalTypes.formUnion([
        HKCategoryType.categoryType(forIdentifier: .contraceptive)!,
        HKCategoryType.categoryType(forIdentifier: .pregnancyTestResult)!,
        HKCategoryType.categoryType(forIdentifier: .progesteroneTestResult)!,
      ])
    }

    if #available(iOS 16.0, *) {
      optionalTypes.formUnion([
        HKCategoryType.categoryType(forIdentifier: .persistentIntermenstrualBleeding)!,
        HKCategoryType.categoryType(forIdentifier: .prolongedMenstrualPeriods)!,
        HKCategoryType.categoryType(forIdentifier: .irregularMenstrualCycles)!,
        HKCategoryType.categoryType(forIdentifier: .infrequentMenstrualCycles)!,
      ])
    }

    return HealthKitObjectTypeRequirements(
      required: [
        HKCategoryType.categoryType(forIdentifier: .menstrualFlow)!,
      ],
      optional: optionalTypes,
      supplementary: supplementaryTypes
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
  var menstrualCycleTypes: [HKSampleType] = [
    HKCategoryType.categoryType(forIdentifier: .menstrualFlow)!,
    HKCategoryType.categoryType(forIdentifier: .cervicalMucusQuality)!,
    HKCategoryType.categoryType(forIdentifier: .intermenstrualBleeding)!,
    HKCategoryType.categoryType(forIdentifier: .ovulationTestResult)!,
    HKCategoryType.categoryType(forIdentifier: .sexualActivity)!,
    HKQuantityType.quantityType(forIdentifier: .basalBodyTemperature)!,
  ]

  if #available(iOS 15.0, *) {
    menstrualCycleTypes.append(contentsOf: [
      HKCategoryType.categoryType(forIdentifier: .contraceptive)!,
      HKCategoryType.categoryType(forIdentifier: .pregnancyTestResult)!,
      HKCategoryType.categoryType(forIdentifier: .progesteroneTestResult)!,
    ])
  }

  if #available(iOS 16.0, *) {
    menstrualCycleTypes.append(contentsOf: [
      HKCategoryType.categoryType(forIdentifier: .persistentIntermenstrualBleeding)!,
      HKCategoryType.categoryType(forIdentifier: .prolongedMenstrualPeriods)!,
      HKCategoryType.categoryType(forIdentifier: .irregularMenstrualCycles)!,
      HKCategoryType.categoryType(forIdentifier: .infrequentMenstrualCycles)!,
    ])
  }

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

    /// Menstrual Cycle
    menstrualCycleTypes,

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
) -> Set<VitalResource> {

  var resources: Set<VitalResource> = []

  for resource in VitalResource.all {
    let hasAskedPermission = store.hasAskedForPermission(resource)
    if hasAskedPermission {
      resources.insert(resource)
    }
  }
  
  return resources
}
