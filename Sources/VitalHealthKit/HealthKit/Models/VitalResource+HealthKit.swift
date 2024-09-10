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
///
/// In both cases, `supplementary` is not considered at all.
///
/// A rule of thumb is that `supplementary` should be used over `optional` when the VitalResource should
/// be considered as INACTIVE iff:
/// 1. ONLY one or more supplementary sample types are granted;
/// 2. NONE of the optional sample types are granted;
/// 3. the resource has no required sample types.
///
/// Some sample types may appear in multiple `VitalResource`s:
/// 1. Each sample type can only be associated with ** one** VitalResource as their `required` types.
/// 2. A sample type can be present an `optional` or `supplementary` type as many VitalResource as needed.
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
      optional: [],
      supplementary: [
        HKSampleType.quantityType(forIdentifier: .respiratoryRate)!,
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

  case .vitals(.respiratoryRate):
    return single(.quantityType(forIdentifier: .respiratoryRate)!)

  case .vitals(.temperature):
    return single(.quantityType(forIdentifier: .bodyTemperature)!)

  case .meal:

    return HealthKitObjectTypeRequirements(
      required: [],
      optional: [
        HKQuantityType.quantityType(forIdentifier: .dietaryBiotin)!,
        HKQuantityType.quantityType(forIdentifier: .dietaryEnergyConsumed)!,
        HKQuantityType.quantityType(forIdentifier: .dietaryCarbohydrates)!,
        HKQuantityType.quantityType(forIdentifier: .dietaryFiber)!,
        HKQuantityType.quantityType(forIdentifier: .dietarySugar)!,
        HKQuantityType.quantityType(forIdentifier: .dietaryFatTotal)!,
        HKQuantityType.quantityType(forIdentifier: .dietaryFatMonounsaturated)!,
        HKQuantityType.quantityType(forIdentifier: .dietaryFatPolyunsaturated)!,
        HKQuantityType.quantityType(forIdentifier: .dietaryFatSaturated)!,
        HKQuantityType.quantityType(forIdentifier: .dietaryCholesterol)!,
        HKQuantityType.quantityType(forIdentifier: .dietaryProtein)!,
        HKQuantityType.quantityType(forIdentifier: .dietaryVitaminA)!,
        HKQuantityType.quantityType(forIdentifier: .dietaryThiamin)!,
        HKQuantityType.quantityType(forIdentifier: .dietaryRiboflavin)!,
        HKQuantityType.quantityType(forIdentifier: .dietaryNiacin)!,
        HKQuantityType.quantityType(forIdentifier: .dietaryPantothenicAcid)!,
        HKQuantityType.quantityType(forIdentifier: .dietaryVitaminB6)!,
        HKQuantityType.quantityType(forIdentifier: .dietaryBiotin)!,
        HKQuantityType.quantityType(forIdentifier: .dietaryVitaminB12)!,
        HKQuantityType.quantityType(forIdentifier: .dietaryVitaminC)!,
        HKQuantityType.quantityType(forIdentifier: .dietaryVitaminD)!,
        HKQuantityType.quantityType(forIdentifier: .dietaryVitaminE)!,
        HKQuantityType.quantityType(forIdentifier: .dietaryVitaminK)!,
        HKQuantityType.quantityType(forIdentifier: .dietaryFolate)!,
        HKQuantityType.quantityType(forIdentifier: .dietaryCalcium)!,
        HKQuantityType.quantityType(forIdentifier: .dietaryChloride)!,
        HKQuantityType.quantityType(forIdentifier: .dietaryIron)!,
        HKQuantityType.quantityType(forIdentifier: .dietaryMagnesium)!,
        HKQuantityType.quantityType(forIdentifier: .dietaryPhosphorus)!,
        HKQuantityType.quantityType(forIdentifier: .dietaryPotassium)!,
        HKQuantityType.quantityType(forIdentifier: .dietarySodium)!,
        HKQuantityType.quantityType(forIdentifier: .dietaryZinc)!,
        HKQuantityType.quantityType(forIdentifier: .dietaryChromium)!,
        HKQuantityType.quantityType(forIdentifier: .dietaryCopper)!,
        HKQuantityType.quantityType(forIdentifier: .dietaryIodine)!,
        HKQuantityType.quantityType(forIdentifier: .dietaryManganese)!,
        HKQuantityType.quantityType(forIdentifier: .dietaryMolybdenum)!,
        HKQuantityType.quantityType(forIdentifier: .dietarySelenium)!,
      ],
      supplementary: []
    )
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

    /// Meal
    [
      HKQuantityType.quantityType(forIdentifier: .dietaryBiotin)!,
      HKQuantityType.quantityType(forIdentifier: .dietaryEnergyConsumed)!,
      HKQuantityType.quantityType(forIdentifier: .dietaryCarbohydrates)!,
      HKQuantityType.quantityType(forIdentifier: .dietaryFiber)!,
      HKQuantityType.quantityType(forIdentifier: .dietarySugar)!,
      HKQuantityType.quantityType(forIdentifier: .dietaryFatTotal)!,
      HKQuantityType.quantityType(forIdentifier: .dietaryFatMonounsaturated)!,
      HKQuantityType.quantityType(forIdentifier: .dietaryFatPolyunsaturated)!,
      HKQuantityType.quantityType(forIdentifier: .dietaryFatSaturated)!,
      HKQuantityType.quantityType(forIdentifier: .dietaryCholesterol)!,
      HKQuantityType.quantityType(forIdentifier: .dietaryProtein)!,
      HKQuantityType.quantityType(forIdentifier: .dietaryVitaminA)!,
      HKQuantityType.quantityType(forIdentifier: .dietaryThiamin)!,
      HKQuantityType.quantityType(forIdentifier: .dietaryRiboflavin)!,
      HKQuantityType.quantityType(forIdentifier: .dietaryNiacin)!,
      HKQuantityType.quantityType(forIdentifier: .dietaryPantothenicAcid)!,
      HKQuantityType.quantityType(forIdentifier: .dietaryVitaminB6)!,
      HKQuantityType.quantityType(forIdentifier: .dietaryBiotin)!,
      HKQuantityType.quantityType(forIdentifier: .dietaryVitaminB12)!,
      HKQuantityType.quantityType(forIdentifier: .dietaryVitaminC)!,
      HKQuantityType.quantityType(forIdentifier: .dietaryVitaminD)!,
      HKQuantityType.quantityType(forIdentifier: .dietaryVitaminE)!,
      HKQuantityType.quantityType(forIdentifier: .dietaryVitaminK)!,
      HKQuantityType.quantityType(forIdentifier: .dietaryFolate)!,
      HKQuantityType.quantityType(forIdentifier: .dietaryCalcium)!,
      HKQuantityType.quantityType(forIdentifier: .dietaryChloride)!,
      HKQuantityType.quantityType(forIdentifier: .dietaryIron)!,
      HKQuantityType.quantityType(forIdentifier: .dietaryMagnesium)!,
      HKQuantityType.quantityType(forIdentifier: .dietaryPhosphorus)!,
      HKQuantityType.quantityType(forIdentifier: .dietaryPotassium)!,
      HKQuantityType.quantityType(forIdentifier: .dietarySodium)!,
      HKQuantityType.quantityType(forIdentifier: .dietaryZinc)!,
      HKQuantityType.quantityType(forIdentifier: .dietaryChromium)!,
      HKQuantityType.quantityType(forIdentifier: .dietaryCopper)!,
      HKQuantityType.quantityType(forIdentifier: .dietaryIodine)!,
      HKQuantityType.quantityType(forIdentifier: .dietaryManganese)!,
      HKQuantityType.quantityType(forIdentifier: .dietaryMolybdenum)!,
      HKQuantityType.quantityType(forIdentifier: .dietarySelenium)!,
      HKQuantityType.quantityType(forIdentifier: .dietaryWater)!,
      HKQuantityType.quantityType(forIdentifier: .dietaryCaffeine)!
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
    ],

    /// Temperature
    [
      HKSampleType.quantityType(forIdentifier: .bodyTemperature)!
    ],

    /// Respiratory rate
    [
      HKSampleType.quantityType(forIdentifier: .respiratoryRate)!
    ],
  ]
}

func authorizationState(
  store: VitalHealthKitStore
) -> (activeResources: Set<RemappedVitalResource>, determinedObjectTypes: Set<HKObjectType>) {

  var resources: Set<RemappedVitalResource> = []
  var determined: Set<HKObjectType> = []

  for resource in VitalResource.all {
    let state = store.authorizationState(resource)
    if state.isActive {
      resources.insert(VitalHealthKitStore.remapResource(resource))
    }
    determined.formUnion(state.determined)
  }
  
  return (resources, determined)
}
