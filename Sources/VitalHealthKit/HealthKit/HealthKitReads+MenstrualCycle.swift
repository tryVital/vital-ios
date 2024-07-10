import HealthKit
import VitalCore

func handleMenstrualCycle(
  healthKitStore: HKHealthStore,
  vitalStorage: VitalHealthKitStorage,
  instruction: SyncInstruction
) async throws -> (menstrualCycles: [LocalMenstrualCycle], anchors: [StoredAnchor]) {

  var types: Set<HKSampleType> = [
    HKCategoryType.categoryType(forIdentifier: .menstrualFlow)!,
    HKCategoryType.categoryType(forIdentifier: .cervicalMucusQuality)!,
    HKCategoryType.categoryType(forIdentifier: .intermenstrualBleeding)!,
    HKCategoryType.categoryType(forIdentifier: .ovulationTestResult)!,
    HKCategoryType.categoryType(forIdentifier: .sexualActivity)!,
    HKQuantityType.quantityType(forIdentifier: .basalBodyTemperature)!,
  ]

  if #available(iOS 15.0, *) {
    types.formUnion([
      HKCategoryType.categoryType(forIdentifier: .contraceptive)!,
      HKCategoryType.categoryType(forIdentifier: .pregnancyTestResult)!,
      HKCategoryType.categoryType(forIdentifier: .progesteroneTestResult)!,
    ])
  }

  if #available(iOS 16.0, *) {
    types.formUnion([
      HKCategoryType.categoryType(forIdentifier: .persistentIntermenstrualBleeding)!,
      HKCategoryType.categoryType(forIdentifier: .prolongedMenstrualPeriods)!,
      HKCategoryType.categoryType(forIdentifier: .irregularMenstrualCycles)!,
      HKCategoryType.categoryType(forIdentifier: .infrequentMenstrualCycles)!,
    ])
  }

  let searchLowerBound: Date

  // Look back ~3 cycles, just in case
  // These data are manually entered daily entries, so the volume of data are not of concern.
  switch instruction.stage {
  case .historical:
    searchLowerBound = Date.dateAgo(instruction.query.lowerBound, days: 90)
  case .daily:
    searchLowerBound = Date.dateAgo(instruction.query.upperBound, days: 90)
  }

  let sampleGroups = try await queryMulti(
    healthKitStore: healthKitStore,
    vitalStorage: vitalStorage,
    types: types,
    startDate: searchLowerBound,
    endDate: instruction.query.upperBound
  )

  let cycles = processMenstrualCycleSamples(sampleGroups)

  var anchors: [StoredAnchor] = []

  if !cycles.isEmpty {
    anchors.append(
      StoredAnchor(key: "menstrual_cycle", anchor: nil, date: Date(), vitalAnchors: nil)
    )
  }

  return (menstrualCycles: cycles, anchors: anchors)
}

func processMenstrualCycleSamples(_ groups: [HKSampleType: [HKSample]]) -> [LocalMenstrualCycle] {
  return []
}
