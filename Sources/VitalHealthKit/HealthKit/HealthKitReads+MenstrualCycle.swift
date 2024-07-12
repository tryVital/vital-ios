import HealthKit
import VitalCore

@HealthKitActor
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

  // Use end-of-day (exclusive) as the search upper bound.
  // Apple Health writes calendar date bound samples at UTC noon (12:00:00Z).
  let searchUpperBound = instruction.query.upperBound.dayEnd

  let sampleGroups = try await queryMulti(
    healthKitStore: healthKitStore,
    vitalStorage: vitalStorage,
    types: types,
    startDate: searchLowerBound,
    endDate: searchUpperBound
  )

  let cycles = splitGroupBySourceBundle(sampleGroups)
    .flatMap { processMenstrualCycleSamples($1, fromSourceBundle: $0) }

  let currentHash = try deterministicHash(for: cycles)

  let previousAnchor = vitalStorage.read(key: "menstrual_cycle")
  let previousHash = previousAnchor?.vitalAnchors?.first?.id

  let newAnchors = [
    StoredAnchor(
      key: "menstrual_cycle",
      anchor: nil,
      date: Date(),
      vitalAnchors: [VitalAnchor(id: currentHash)]
    )
  ]

  VitalLogger.healthKit.info("hash: prev = \(previousHash ?? "nil"); curr = \(currentHash)", source: "MenstrualCycle")

  if previousHash != currentHash {
    return (menstrualCycles: cycles, anchors: newAnchors)

  } else {
    return (menstrualCycles: [], anchors: newAnchors)
  }

}

func deterministicHash<T: Encodable>(for content: T) throws -> String {
  let encoder = JSONEncoder()
  encoder.outputFormatting = [.sortedKeys]

  return try encoder.encode(content).base64EncodedSHA256()
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
    guard let samples = groups[type] else { return [:] }

    // Simple O(N*M) algorithm since the number of entries is low.
    return Dictionary(
      uniqueKeysWithValues: boundaries.map { boundary in
        (
          boundary,
          samples.compactMap { sample -> Entry? in
            let startDate = sample.calendarDate(of: \.startDate)
            guard boundary.contains(startDate) else { return nil }

            let entry = transform(startDate, sample as! Sample)
            return entry
          }
        )
      }
    )
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

  let sexualActivity = groupSamplesByBoundary(
    .categoryType(forIdentifier: .sexualActivity)!,
    boundaries: cycleBoundaries,
    sampleClass: HKCategorySample.self,
    transform: { date, sample -> MenstrualCycle.SexualActivityEntry? in
      let protectionUsed = sample.metadata?[HKMetadataKeySexualActivityProtectionUsed] as? Bool
      return MenstrualCycle.SexualActivityEntry(date: date, protectionUsed: protectionUsed)
    }
  )

  let ovulationTest = groupSamplesByBoundary(
    .categoryType(forIdentifier: .ovulationTestResult)!,
    boundaries: cycleBoundaries,
    sampleClass: HKCategorySample.self,
    transform: { date, sample -> MenstrualCycle.OvulationTestEntry? in
      guard
        let healthKitValue = HKCategoryValueOvulationTestResult(rawValue: sample.value),
        let value = MenstrualCycle.OvulationTestResult(healthKitValue)
      else { return nil }

      return MenstrualCycle.OvulationTestEntry(date: date, testResult: value)
    }
  )

  let basalBodyTemperature = groupSamplesByBoundary(
    .quantityType(forIdentifier: .basalBodyTemperature)!,
    boundaries: cycleBoundaries,
    sampleClass: HKQuantitySample.self,
    transform: { date, sample -> MenstrualCycle.BasalBodyTemperatureEntry? in
      MenstrualCycle.BasalBodyTemperatureEntry(
        date: date,
        value: sample.quantity.doubleValue(for: .degreeCelsius())
      )
    }
  )

  let contraceptive: [CycleBoundary: [MenstrualCycle.ContraceptiveEntry]]
  let homePregnancyTest: [CycleBoundary: [MenstrualCycle.HomePregnancyTestEntry]]
  let homeProgesteroneTest: [CycleBoundary: [MenstrualCycle.HomeProgesteroneTestEntry]]
  var detectedDeviations: [CycleBoundary: [MenstrualCycle.DetectedDeviationEntry]] = [:]

  if #available(iOS 15.0, *) {
    contraceptive = groupSamplesByBoundary(
      .categoryType(forIdentifier: .contraceptive)!,
      boundaries: cycleBoundaries,
      sampleClass: HKCategorySample.self,
      transform: { date, sample -> MenstrualCycle.ContraceptiveEntry? in
        guard
          let healthKitValue = HKCategoryValueContraceptive(rawValue: sample.value),
          let value = MenstrualCycle.ContraceptiveType(healthKitValue)
        else { return nil }

        return MenstrualCycle.ContraceptiveEntry(date: date, type: value)
      }
    )

    homePregnancyTest = groupSamplesByBoundary(
      .categoryType(forIdentifier: .pregnancyTestResult)!,
      boundaries: cycleBoundaries,
      sampleClass: HKCategorySample.self,
      transform: { date, sample -> MenstrualCycle.HomePregnancyTestEntry? in
        guard
          let healthKitValue = HKCategoryValuePregnancyTestResult(rawValue: sample.value),
          let value = MenstrualCycle.HomeTestResult(healthKitValue)
        else { return nil }

        return MenstrualCycle.HomePregnancyTestEntry(date: date, testResult: value)
      }
    )

    homeProgesteroneTest = groupSamplesByBoundary(
      .categoryType(forIdentifier: .progesteroneTestResult)!,
      boundaries: cycleBoundaries,
      sampleClass: HKCategorySample.self,
      transform: { date, sample -> MenstrualCycle.HomeProgesteroneTestEntry? in
        guard
          let healthKitValue = HKCategoryValueProgesteroneTestResult(rawValue: sample.value),
          let value = MenstrualCycle.HomeTestResult(healthKitValue)
        else { return nil }

        return MenstrualCycle.HomeProgesteroneTestEntry(date: date, testResult: value)
      }
    )

  } else {
    contraceptive = [:]
    homePregnancyTest = [:]
    homeProgesteroneTest = [:]
  }


  if #available(iOS 16.0, *) {
    detectedDeviations = [:]
    func processDeviations(
      _ identifier: HKCategoryTypeIdentifier,
      _ deviation: MenstrualCycle.MenstrualDeviation
    ) {
      let entries = groupSamplesByBoundary(
        .categoryType(forIdentifier: identifier)!,
        boundaries: cycleBoundaries,
        sampleClass: HKCategorySample.self,
        transform: { date, sample -> MenstrualCycle.DetectedDeviationEntry? in
          return MenstrualCycle.DetectedDeviationEntry(date: date, deviation: deviation)
        }
      )

      for (date, entries) in entries {
        detectedDeviations[date, default: []].append(contentsOf: entries)
      }
    }

    processDeviations(.persistentIntermenstrualBleeding, .persistentIntermenstrualBleeding)
    processDeviations(.infrequentMenstrualCycles, .infrequentMenstrualCycles)
    processDeviations(.prolongedMenstrualPeriods, .prolongedMenstrualPeriods)
    processDeviations(.irregularMenstrualCycles, .irregularMenstrualCycles)
  }


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
        contraceptive: contraceptive[cycle] ?? [],
        detectedDeviations: detectedDeviations[cycle] ?? [],
        ovulationTest: ovulationTest[cycle] ?? [],
        homePregnancyTest: homePregnancyTest[cycle] ?? [],
        homeProgesteroneTest: homeProgesteroneTest[cycle] ?? [],
        sexualActivity: sexualActivity[cycle] ?? [],
        basalBodyTemperature: basalBodyTemperature[cycle] ?? [],
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

  func contains(_ date: GregorianCalendar.Date) -> Bool {
    if let cycleEnd = cycleEnd {
      return cycleStart <= date && date <= cycleEnd
    }

    return cycleStart <= date
  }
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

extension MenstrualCycle.ContraceptiveType {
  @available(iOS 15.0, *)
  init?(_ category: HKCategoryValueContraceptive) {
    switch category {
    case .implant:
      self = .implant
    case .injection:
      self = .injection
    case .intrauterineDevice:
      self = .iud
    case .intravaginalRing:
      self = .intravaginalRing
    case .oral:
      self = .oral
    case .patch:
      self = .patch
    case .unspecified:
      self = .unspecified
    @unknown default:
      return nil
    }
  }
}

extension MenstrualCycle.HomeTestResult {
  @available(iOS 15.0, *)
  init?(_ category: HKCategoryValuePregnancyTestResult) {
    switch category {
    case .indeterminate:
      self = .indeterminate
    case .negative:
      self = .negative
    case .positive:
      self = .positive
    @unknown default:
      return nil
    }
  }
}

extension MenstrualCycle.HomeTestResult {
  @available(iOS 15.0, *)
  init?(_ category: HKCategoryValueProgesteroneTestResult) {
    switch category {
    case .indeterminate:
      self = .indeterminate
    case .negative:
      self = .negative
    case .positive:
      self = .positive
    @unknown default:
      return nil
    }
  }
}

extension MenstrualCycle.OvulationTestResult {
  init?(_ category: HKCategoryValueOvulationTestResult) {
    switch category {
    case .estrogenSurge:
      self = .estrogenSurge
    case .luteinizingHormoneSurge:
      self = .luteinizingHormoneSurge
    case .negative:
      self = .negative
    case .indeterminate:
      self = .indeterminate
    @unknown default:
      return nil
    }
  }
}
