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

  let cycles = splitGroupBySourceBundle(sampleGroups)
    .flatMap { processMenstrualCycleSamples($1, fromSourceBundle: $0) }

  var anchors: [StoredAnchor] = []

  if !cycles.isEmpty {
    anchors.append(
      StoredAnchor(key: "menstrual_cycle", anchor: nil, date: Date(), vitalAnchors: nil)
    )
  }

  return (menstrualCycles: cycles, anchors: anchors)
}

func splitGroupBySourceBundle(_ groups: [HKSampleType: [HKSample]]) -> [String: [HKSampleType: [HKSample]]] {
  var groupBySource: [String: [HKSampleType: [HKSample]]] = [:]

  for (type, samples) in groups {
    for sample in samples {
      let bundle = sample.sourceRevision.source.bundleIdentifier
      groupBySource[bundle, default: [:]][type, default: []].append(sample)
    }
  }

  return groupBySource
}


func processMenstrualCycleSamples(_ groups: [HKSampleType: [HKSample]], fromSourceBundle sourceBundle: String) -> [LocalMenstrualCycle] {

  /// Menstrual Flow samples define the cycle boundary.
  /// If we cannot find any, then we cannot have no boundary to properly contextualize other data.
  guard let menstrualFlowSamples = groups[HKCategoryType.categoryType(forIdentifier: .menstrualFlow)!] else {
    return []
  }

  /// The logic is developed against how Apple Health writes menstrual data into HealthKit.
  /// Might need to tweak later for third-party writers.

  var cycleBoundaries: [CycleBoundary] = []

  // queryMulti returns sample in `startDate` ascending order.
  var currentCycleStart: GregorianCalendar.Date?
  var currentPeriodEnd: GregorianCalendar.Date?

  func endCurrentCycle(withNewPeriodStart newStart: GregorianCalendar.Date?) {
    guard let cycleStart = currentCycleStart else {
      return
    }

    cycleBoundaries.append(
      CycleBoundary(
        cycleStart: cycleStart,
        periodEnd: currentPeriodEnd,
        cycleEnd: newStart.map { GregorianCalendar.utc.offset($0, byDays: -1) }
      )
    )

    currentCycleStart = nil
    currentPeriodEnd = nil
  }

  for sample in menstrualFlowSamples {
    let cycleStart = sample.metadata?[HKMetadataKeyMenstrualCycleStart] as? Bool ?? false
    let startDate = sample.calendarDate(of: \.startDate)
    let endDate = sample.calendarDate(of: \.endDate)

    if cycleStart {
      endCurrentCycle(withNewPeriodStart: startDate)
      currentCycleStart = startDate
    }

    currentPeriodEnd = endDate
  }

  endCurrentCycle(withNewPeriodStart: nil)

  func groupSamplesByBoundary<Sample: HKSample, Entry>(
    _ type: HKSampleType,
    boundaries: [CycleBoundary],
    sampleClass: Sample.Type,
    transform: (GregorianCalendar.Date, Sample) -> Entry?
  ) -> [CycleBoundary: [Entry]] {
    return [:]
  }

  let menstrualFlows = groupSamplesByBoundary(
    .categoryType(forIdentifier: .menstrualFlow)!,
    boundaries: cycleBoundaries,
    sampleClass: HKCategorySample.self,
    transform: { date, sample -> MenstrualCycle.MenstrualFlowEntry? in
      guard
        let healthKitValue = HKCategoryValueMenstrualFlow(rawValue: sample.value),
        let value = MenstrualCycle.MenstrualFlow(healthKitValue)
      else { return nil }

      return MenstrualCycle.MenstrualFlowEntry(date: date, flow: value)
    }
  )

  let cervicalMucus = groupSamplesByBoundary(
    .categoryType(forIdentifier: .cervicalMucusQuality)!,
    boundaries: cycleBoundaries,
    sampleClass: HKCategorySample.self,
    transform: { date, sample -> MenstrualCycle.CervicalMucusEntry? in
      guard
        let healthKitValue = HKCategoryValueCervicalMucusQuality(rawValue: sample.value),
        let value = MenstrualCycle.CervicalMucusQuality(healthKitValue)
      else { return nil }

      return MenstrualCycle.CervicalMucusEntry(date: date, quality: value)
    }
  )

  let intermenstrualBleeding = groupSamplesByBoundary(
    .categoryType(forIdentifier: .intermenstrualBleeding)!,
    boundaries: cycleBoundaries,
    sampleClass: HKCategorySample.self,
    transform: { date, sample -> MenstrualCycle.IntermenstrualBleedingEntry? in
      MenstrualCycle.IntermenstrualBleedingEntry(date: date)
    }
  )

  return cycleBoundaries.map { cycle in
    LocalMenstrualCycle(
      sourceBundle: sourceBundle,
      cycle: MenstrualCycle(
        periodStart: cycle.cycleStart,
        periodEnd: cycle.periodEnd,
        cycleEnd: cycle.cycleEnd,
        menstrualFlow: menstrualFlows[cycle] ?? [],
        cervicalMucus: cervicalMucus[cycle] ?? [],
        intermenstrualBleeding: intermenstrualBleeding[cycle] ?? [],
        // TODO: VIT-6747
        contraceptive: [],
        detectedDeviations: [],
        ovulationTest: [],
        homePregnancyTest: [],
        homeProgesteroneTest: [],
        sexualActivity: [],
        basalBodyTemperature: [],
        source: Source(
          provider: Provider.Slug.appleHealthKit.rawValue,
          type: .app,
          appId: sourceBundle
        )
      )
    )
  }
}

extension HKSample {
  func calendarDate(of keyPath: KeyPath<HKSample, Date>) -> GregorianCalendar.Date {
    let timeZone = (metadata?[HKMetadataKeyTimeZone]).flatMap { $0 as? String }.flatMap(TimeZone.init(identifier:))
      ?? TimeZone(secondsFromGMT: 0)!

    let date = self[keyPath: keyPath]
    let calendar = GregorianCalendar(timeZone: timeZone)
    return calendar.floatingDate(of: date)
  }
}

struct CycleBoundary: Hashable {
  let cycleStart: GregorianCalendar.Date
  let periodEnd: GregorianCalendar.Date?
  let cycleEnd: GregorianCalendar.Date?
}

extension MenstrualCycle.MenstrualFlow {
  init?(_ category: HKCategoryValueMenstrualFlow) {
    switch category {
    case .heavy:
      self = .heavy
    case .light:
      self = .light
    case .medium:
      self = .medium
    case .unspecified:
      self = .unspecified
    case .none:
      self = .none
    @unknown default:
      return nil
    }
  }
}

extension MenstrualCycle.CervicalMucusQuality {
  init?(_ category: HKCategoryValueCervicalMucusQuality) {
    switch category {
    case .creamy:
      self = .creamy
    case .dry:
      self = .dry
    case .eggWhite:
      self = .eggWhite
    case .sticky:
      self = .sticky
    case .watery:
      self = .watery
    @unknown default:
      return nil
    }
  }
}
