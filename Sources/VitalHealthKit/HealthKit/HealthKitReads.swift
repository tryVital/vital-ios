import HealthKit
import VitalCore
import Accelerate

typealias SampleQueryHandler = (HKSampleQuery, [HKSample]?, Error?) -> Void
typealias AnchorQueryHandler = (HKAnchoredObjectQuery, [HKSample]?, [HKDeletedObject]?, HKQueryAnchor?, Error?) -> Void
typealias ActivityQueryHandler = (HKActivitySummaryQuery, [HKActivitySummary]?, Error?) -> Void

typealias SeriesSampleHandler = (HKQuantitySeriesSampleQuery, HKQuantity?, DateInterval?, HKQuantitySample?, Bool, Error?) -> Void

typealias StatisticsHandler = (HKStatisticsCollectionQuery, HKStatisticsCollection?, Error?) -> Void

typealias HourlyStatisticsResultHandler = (Result<[VitalStatistics], Error>) -> Void

enum VitalHealthKitClientError: Error {
  case invalidInterval(Date, Date, context: StaticString)
  case invalidRemappedResource
  case connectionPaused
  case healthKitInvalidState(String)
}

enum AnchoredQueryChunkSize {
  static let timeseries = 50000
  static let workout = 40
  // IMPORTANT: The current Sleep Session stitching algorithm is not chunkable.
  static let sleep = HKObjectQueryNoLimit
  static let activityTimeseries = 50000
}

struct VitalStatisticsError: Error {
  let statistics: HKStatistics

  var description: String {
    let formatter = ISO8601DateFormatter()
    let start = formatter.string(from: statistics.startDate)
    let end = formatter.string(from: statistics.endDate)
    return "Failed to convert HKStatistics for \(statistics.quantityType.identifier): \(start) -> \(end)"
  }
}

func read(
  resource: RemappedVitalResource,
  healthKitStore: HKHealthStore,
  typeToResource: ((HKSampleType) -> VitalResource),
  vitalStorage: VitalHealthKitStorage,
  instruction: SyncInstruction,
  options: ReadOptions
) async throws -> (ProcessedResourceData?, [StoredAnchor]) {
  
  switch resource.wrapped {
  case .individual:
    throw VitalHealthKitClientError.invalidRemappedResource

    case .profile:
      let profilePayload = try await handleProfile(
        healthKitStore: healthKitStore,
        vitalStorage: vitalStorage
      )

      if let patch = profilePayload.profilePatch {
        return (.summary(.profile(patch)), profilePayload.anchors)
      } else {
        return (nil, [])
      }

    case .body:
      let payload = try await handleBody(
        healthKitStore: healthKitStore,
        vitalStorage: vitalStorage,
        startDate: instruction.query.lowerBound,
        endDate: instruction.query.upperBound
      )
      
      return (.summary(.body(payload.bodyPatch)), payload.anchors)
      
    case .sleep:
      let payload = try await handleSleep(
        healthKitStore: healthKitStore,
        vitalStorage: vitalStorage,
        startDate: instruction.query.lowerBound,
        endDate: instruction.query.upperBound,
        options: options
      )
      
      return (.summary(.sleep(payload.sleepPatch)), payload.anchors)
      
    case .activity:
      let payload = try await handleActivity(
        healthKitStore: healthKitStore,
        vitalStorage: vitalStorage,
        startDate: instruction.query.lowerBound,
        endDate: instruction.query.upperBound,
        options: options
      )
      
      return (payload.activityPatch.map { .summary(.activity($0)) }, payload.anchors)

  case .menstrualCycle:
    let payload = try await handleMenstrualCycle(healthKitStore: healthKitStore, vitalStorage: vitalStorage, instruction: instruction)
    return (
      .summary(.menstrualCycle(MenstrualCyclePatch(cycles: payload.menstrualCycles))),
      payload.anchors
    )

    case .workout:
      let payload = try await handleWorkouts(
        healthKitStore: healthKitStore,
        vitalStorage: vitalStorage,
        startDate: instruction.query.lowerBound,
        endDate: instruction.query.upperBound,
        options: options
      )
      
      return (.summary(.workout(payload.workoutPatch)), payload.anchors)

    case .vitals(.bloodOxygen):
      let payload = try await handleTimeSeries(
        type: .quantityType(forIdentifier: .oxygenSaturation)!,
        healthKitStore: healthKitStore,
        vitalStorage: vitalStorage,
        startDate: instruction.query.lowerBound,
        endDate: instruction.query.upperBound
      )

      return (.timeSeries(.bloodOxygen(payload.samples)), payload.anchors)

    case .vitals(.glucose):
      let payload = try await handleTimeSeries(
        type: .quantityType(forIdentifier: .bloodGlucose)!,
        healthKitStore: healthKitStore,
        vitalStorage: vitalStorage,
        startDate: instruction.query.lowerBound,
        endDate: instruction.query.upperBound
      )
      
      return (.timeSeries(.glucose(payload.samples)), payload.anchors)
      
    case .vitals(.heartRate):
      let payload = try await handleTimeSeries(
        type: .quantityType(forIdentifier: .heartRate)!,
        healthKitStore: healthKitStore,
        vitalStorage: vitalStorage,
        startDate: instruction.query.lowerBound,
        endDate: instruction.query.upperBound
      )
      
      return (.timeSeries(.heartRate(payload.samples)), payload.anchors)

    case .vitals(.heartRateVariability):
      let payload = try await handleTimeSeries(
        type: .quantityType(forIdentifier: .heartRateVariabilitySDNN)!,
        healthKitStore: healthKitStore,
        vitalStorage: vitalStorage,
        startDate: instruction.query.lowerBound,
        endDate: instruction.query.upperBound
      )

      return (.timeSeries(.heartRateVariability(payload.samples)), payload.anchors)
      
    case .vitals(.bloodPressure):
      let payload = try await handleBloodPressure(
        healthKitStore: healthKitStore,
        vitalStorage: vitalStorage,
        startDate: instruction.query.lowerBound,
        endDate: instruction.query.upperBound
      )
      
      return (.timeSeries(.bloodPressure(payload.bloodPressure)), payload.anchors)
      
    case .nutrition(.water):
      let payload = try await handleTimeSeries(
        type: .quantityType(forIdentifier: .dietaryWater)!,
        healthKitStore: healthKitStore,
        vitalStorage: vitalStorage,
        startDate: instruction.query.lowerBound,
        endDate: instruction.query.upperBound
      )
      
      return (.timeSeries(.nutrition(.water(payload.samples))), payload.anchors)

    case .nutrition(.caffeine):
      let payload = try await handleTimeSeries(
        type: .quantityType(forIdentifier: .dietaryCaffeine)!,
        healthKitStore: healthKitStore,
        vitalStorage: vitalStorage,
        startDate: instruction.query.lowerBound,
        endDate: instruction.query.upperBound
      )

      return (.timeSeries(.nutrition(.caffeine(payload.samples))), payload.anchors)

    case .vitals(.mindfulSession):
      let payload = try await handleMindfulSessions(
        healthKitStore: healthKitStore,
        vitalStorage: vitalStorage,
        startDate: instruction.query.lowerBound,
        endDate: instruction.query.upperBound
      )

      return (.timeSeries(.mindfulSession(payload.samples)), payload.anchors)
  }
}

func handleMindfulSessions(
  healthKitStore: HKHealthStore,
  vitalStorage: VitalHealthKitStorage,
  startDate: Date,
  endDate: Date
) async throws -> (samples: [LocalQuantitySample], anchors: [StoredAnchor]) {

  var anchors: [StoredAnchor] = []

  let payload = try await anchoredQuery(
    healthKitStore: healthKitStore,
    vitalStorage: vitalStorage,
    type: .categoryType(forIdentifier: .mindfulSession)!,
    limit: AnchoredQueryChunkSize.timeseries,
    startDate: startDate,
    endDate: endDate
  )

  let samples = payload.sample.compactMap(LocalQuantitySample.fromMindfulSession(sample:))
  anchors.appendOptional(payload.anchor)

  return (samples: samples, anchors: anchors)
}

func handleProfile(
  healthKitStore: HKHealthStore,
  vitalStorage: VitalHealthKitStorage
) async throws -> (profilePatch: ProfilePatch?, anchors: [StoredAnchor]) {

  let storageKey = "profile"

  let sex = try healthKitStore.biologicalSex().biologicalSex
  let biologicalSex = ProfilePatch.BiologicalSex(healthKitSex: sex)

  let dateOfBirth = try healthKitStore.patched_dateOfBirthComponents()
    .flatMap(vitalCalendar.date(from:))

  let payload: [LocalQuantitySample] = try await querySample(
    healthKitStore: healthKitStore,
    type: .quantityType(forIdentifier: .height)!,
    limit: 1,
    ascending: false
  ).compactMap(LocalQuantitySample.init)
  
  let height = payload.last.map { Int($0.value)}
  
  let profile: ProfilePatch = .init(
    biologicalSex: biologicalSex,
    dateOfBirth: dateOfBirth,
    height: height,
    timeZone: TimeZone.current.identifier
  )
  let id = profile.id

  let anchor = vitalStorage.read(key: storageKey)
  let storedId = anchor?.vitalAnchors?.first?.id

  guard let id = id, storedId != id else {
    return (profilePatch: nil, anchors: [])
  }

  return (
    profilePatch: profile,
    anchors: [.init(key: storageKey, anchor: nil, date: Date(), vitalAnchors: [.init(id: id)])]
  )
}

func handleBody(
  healthKitStore: HKHealthStore,
  vitalStorage: VitalHealthKitStorage,
  startDate: Date,
  endDate: Date
) async throws -> (bodyPatch: BodyPatch, anchors: [StoredAnchor]) {
  
  func queryQuantities(
    type: HKSampleType
  ) async throws -> (quantities: [LocalQuantitySample], StoredAnchor?) {
    
    let payload = try await anchoredQuery(
      healthKitStore: healthKitStore,
      vitalStorage: vitalStorage,
      type: type,
      limit: AnchoredQueryChunkSize.timeseries,
      startDate: startDate,
      endDate: endDate
    )
    
    let quantities: [LocalQuantitySample] = payload.sample.compactMap(LocalQuantitySample.init)
    return (quantities, payload.anchor)
  }
  
  
  var anchors: [StoredAnchor] = []
  
  let (bodyMass, bodyMassAnchor) = try await queryQuantities(
    type: .quantityType(forIdentifier: .bodyMass)!
  )
  
  let (bodyFatPercentage, bodyFatPercentageAnchor) = try await queryQuantities(
    type: .quantityType(forIdentifier: .bodyFatPercentage)!
  )
  
  anchors.appendOptional(bodyMassAnchor)
  anchors.appendOptional(bodyFatPercentageAnchor)
  
  return (
    .init(
      bodyMass: bodyMass,
      bodyFatPercentage: bodyFatPercentage
    ),
    anchors
  )
}

func handleSleep(
  healthKitStore: HKHealthStore,
  vitalStorage: VitalHealthKitStorage,
  startDate: Date,
  endDate: Date,
  options: ReadOptions
) async throws -> (sleepPatch: SleepPatch, anchors: [StoredAnchor]) {
  
  var anchors: [StoredAnchor] = []
  let sleepType = HKSampleType.categoryType(forIdentifier: .sleepAnalysis)!
  
  var predicate: NSPredicate?
  if #available(iOS 16.0, *) {
    predicate = HKCategoryValueSleepAnalysis.predicateForSamples(equalTo: [.asleepUnspecified, .asleepCore, .asleepREM, .asleepDeep, .awake, .inBed])
  }
  
  let payload = try await anchoredQuery(
    healthKitStore: healthKitStore,
    vitalStorage: vitalStorage,
    type: sleepType,
    limit: AnchoredQueryChunkSize.sleep,
    startDate: startDate,
    endDate: endDate,
    extraPredicate: predicate
  )

  anchors.appendOptional(payload.anchor)

  /// An iPhone is capable of recording sleep. We can see it by looking at the bundle identifier + productType.
  /// However we are only interested in sleep recorded with an Apple Watch.
  /// This filter discards iPhone recorded sleeps.
  ///
  ///
  /// NOTE: We are disabling  this for now. VIT-4156
  //  let sampleWithoutPhone = filterForWatch(samples: payload.sample)
  
  /// The goal of this filter is to remove sleep data generated by 3rd party apps that only do analyses.
  /// Apps like Pillow and SleepWatch are great, but we are only interested in data generated by devices (e.g. Apple Watch, Oura)
  let admittedSamples = filter(samples: payload.sample, by: DataSource.allCases)

  /// Group the sleeps by source bundle before we try to stitch them into sleep sessions.
  let samplesBySourceBundle = Dictionary(
    grouping: admittedSamples,
    by: { SleepGroupKey(bundleIdentifier: $0.sourceRevision.source.bundleIdentifier, productType: $0.sourceRevision.productType) }
  )

  var copies: [SleepPatch.Sleep] = []

  for (groupKey, sampleGroup) in samplesBySourceBundle {
    let sourceRevision = sampleGroup[0].sourceRevision

    /// Sorting by start date is essential here, since HKAnchoredObjectQuery returns samples in insertion order.
    /// There is otherwise no guarantee of samples being somewhat chornologically ordered, and being so are important to
    /// achieve consistent and quality stitches across all sorts of HealthKit writers.
    var sleeps = sampleGroup.compactMap(SleepPatch.Sleep.init)
    sleeps.sort { $0.startDate < $1.startDate }

    /// Sleep samples can be sliced up. For example you can have a slice going from `2022-09-08 22:00` to `2022-09-08 22:15`
    /// And several others until the last one is `2022-09-09 07:00`. The goal of of `stitchedSleeps` is to put all these slices together
    /// Into a single `SleepPatch.Sleep` going from `2022-09-08 22:00` to `2022-09-08 22:15`
    let stitchedData = stitchedSleeps(sleeps: sleeps, sourceType: groupKey.sourceType)

    /// `stitchedSleeps` doesn't deal with non-consecutive samples. So it's possible to have a sequence of samples that belong to different
    /// providers (e.g. Apple Watch, Oura, Fitbit). The goal of `mergeSleeps` is to find overlapping sleeps that belong to the same provider and merge them
    let mergedData = mergeSleeps(sleeps: stitchedData)

    for var sleep in mergedData {
      func fitSamples(
        sleep: inout SleepPatch.Sleep
      ) {
        for filteredSample in sampleGroup {
          if let categorySample = filteredSample as? HKCategorySample,
             let sleepAnalysis = HKCategoryValueSleepAnalysis(rawValue: categorySample.value),
             filteredSample.sourceRevision.productType == sleep.productType &&
              filteredSample.sourceRevision.source.bundleIdentifier == sleep.sourceBundle &&
              filteredSample.startDate >= sleep.startDate && filteredSample.endDate <= sleep.endDate

          {
            let sample = LocalQuantitySample(categorySample: categorySample)
            switch sleepAnalysis {
            case .asleepUnspecified:
              sleep.sleepStages.unspecifiedSleepSamples.append(sample)

            case .awake:
              sleep.sleepStages.awakeSleepSamples.append(sample)

            case .asleepCore:
              sleep.sleepStages.lightSleepSamples.append(sample)

            case .asleepREM:
              sleep.sleepStages.remSleepSamples.append(sample)

            case .asleepDeep:
              sleep.sleepStages.deepSleepSamples.append(sample)

            case .inBed:
              sleep.sleepStages.inBedSleepSamples.append(sample)

            @unknown default:
              sleep.sleepStages.unknownSleepSamples.append(sample)
            }
          }
        }
      }

      if #available(iOS 16.0, *) {
        fitSamples(sleep: &sleep)
      }

      var heartRate: [LocalQuantitySample] = []
      var hearRateVariability: [LocalQuantitySample] = []
      var respiratoryRate: [LocalQuantitySample] = []

      let fromSameSourceRevision = NSPredicate(format: "%K == %@", HKPredicateKeyPathSourceRevision, sourceRevision)

      if options.embedTimeseries {
        heartRate = try await querySample(
          healthKitStore: healthKitStore,
          type: .quantityType(forIdentifier: .heartRate)!,
          startDate: sleep.startDate,
          endDate: sleep.endDate,
          extraPredicates: [fromSameSourceRevision]
        )
          .compactMap(LocalQuantitySample.init)

        hearRateVariability = try await querySample(
          healthKitStore: healthKitStore,
          type: .quantityType(forIdentifier: .heartRateVariabilitySDNN)!,
          startDate: sleep.startDate,
          endDate: sleep.endDate,
          extraPredicates: [fromSameSourceRevision]
        )
          .compactMap(LocalQuantitySample.init)

        respiratoryRate = try await querySample(
          healthKitStore: healthKitStore,
          type: .quantityType(forIdentifier: .respiratoryRate)!,
          startDate: sleep.startDate,
          endDate: sleep.endDate,
          extraPredicates: [fromSameSourceRevision]
        )
          .compactMap(LocalQuantitySample.init)
      }

      let wristTemperature: [LocalQuantitySample]

      if #available(iOS 16.0, *) {
        wristTemperature = try await querySample(
          healthKitStore: healthKitStore,
          type: .quantityType(forIdentifier: .appleSleepingWristTemperature)!,
          startDate: sleep.startDate,
          endDate: sleep.endDate,
          extraPredicates: [fromSameSourceRevision],
          // `appleSleepingWristTemperature` sometimes falls outside the bounds of a sleep
          // This means that if we use `strictStartDate` we won't pick up these values.
          options: []
        )
        .filter(by: sleep.sourceBundle)
        .compactMap(LocalQuantitySample.init)
      } else {
        wristTemperature = []
      }

      let stats = StatisticsQueryDependencies.live(healthKitStore: healthKitStore, vitalStorage: vitalStorage)
      let queryInterval = sleep.startDate ..< sleep.endDate
      let predicates = Predicates([fromSameSourceRevision])

      async let _heartRateStatistics = try stats.executeSingleStatisticsQuery(
        HKQuantityType.quantityType(forIdentifier: .heartRate)!,
        queryInterval,
        [.discreteMin, .discreteMax, .discreteAverage],
        predicates
      )

      async let _hrvStatistics = try await stats.executeSingleStatisticsQuery(
        HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!,
        queryInterval,
        [.discreteAverage],
        predicates
      )

      var copy = sleep

      let heartRateStatistics = try await _heartRateStatistics
      let heartRateUnit = HKUnit.count().unitDivided(by: .minute())
      copy.heartRateMean = (heartRateStatistics?.averageQuantity()?.doubleValue(for: heartRateUnit)).map(Int.init)
      copy.heartRateMinimum = (heartRateStatistics?.minimumQuantity()?.doubleValue(for: heartRateUnit)).map(Int.init)
      copy.heartRateMaximum = (heartRateStatistics?.maximumQuantity()?.doubleValue(for: heartRateUnit)).map(Int.init)

      let hrvStatistics = try await _hrvStatistics
      copy.hrvMeanSdnn = hrvStatistics?.averageQuantity()?.doubleValue(for: .secondUnit(with: .milli))

      copy.heartRate = heartRate
      copy.heartRateVariability = hearRateVariability
      copy.respiratoryRate = respiratoryRate
      copy.wristTemperature = wristTemperature

      copies.append(copy)
    }
  }

  return (.init(sleep: copies), anchors)
}

func handleActivity(
  healthKitStore: HKHealthStore,
  vitalStorage: VitalHealthKitStorage,
  startDate: Date,
  endDate: Date,
  options: ReadOptions
) async throws -> (activityPatch: ActivityPatch?, anchors: [StoredAnchor]) {

  let dependencies = StatisticsQueryDependencies.live(
    healthKitStore: healthKitStore,
    vitalStorage: vitalStorage
  )

  // Calendar in local TZ, used for day summaries and final sample grouping.
  let deviceTimeZoneCalendar = GregorianCalendar(timeZone: .current)

  @Sendable func queryQuantities(
    type: HKSampleType
  ) async throws -> (quantities: [LocalQuantitySample], StoredAnchor?) {

    let discoveryStartDate: Date

    // One-off migration for hourly statistics previously using content hash anchors (`[VitalAnchor]`)
    // to HKQueryAnchor.
    if
      let anchor = vitalStorage.read(key: String(describing: type)),
      !(anchor.vitalAnchors?.isEmpty ?? true),
      let lastSyncDate = anchor.date
    {
      // Migration process:
      // 1. Override `startDate` to lastSyncDate - 7 days.
      // 2. `query(...)` bootstraps the HKAnchoredObjectQuery using the overriden `startDate`.
      // 3. `query(...)` returns a `StoredAnchor` containing only a `HKQueryAnchor` and the date.
      // 4. After posting data successfully, we commit the `StoreAnchor`, during which the content
      //    hash anchors (`[VitalAnchor]`) would be deleted.
      // 5. Migration completed — all future sync would not enter this migration path again.
      discoveryStartDate = min(Date.dateAgo(lastSyncDate, days: 7), endDate)

    } else {
      discoveryStartDate = startDate
    }

    let payload = try await anchoredQuery(
      healthKitStore: healthKitStore,
      vitalStorage: vitalStorage,
      type: type,
      limit: AnchoredQueryChunkSize.activityTimeseries,
      startDate: discoveryStartDate,
      endDate: endDate
    )
    
    let quantities: [LocalQuantitySample] = payload.sample.compactMap(LocalQuantitySample.init)
    return (quantities, payload.anchor)
  }

  @Sendable
  func queryHourlyStatistics(
    type: HKQuantityType,
    discovered newSamples: [LocalQuantitySample]
  ) async throws -> [LocalQuantitySample] {
    guard newSamples.isEmpty == false else {
      return []
    }

    var earliest = newSamples[0].startDate
    var latest = newSamples[0].endDate

    for sample in newSamples.dropFirst() {
      earliest = min(earliest, sample.startDate)
      latest = max(latest, sample.endDate)
    }

    // Round down earliest to the start of the whole hour
    // Round up latest to the next whole hour
    earliest = earliest.beginningHour
    latest = latest.nextHour

    let statistics = try await dependencies.executeStatisticalQuery(type, earliest ..< latest, .hourly, nil)

    return statistics.compactMap { value in
      return LocalQuantitySample(value, type)
    }
  }

  // - Hourly timeseries samples
  var anchors: [StoredAnchor] = []

  async let _rawActiveEnergyBurned = queryQuantities(type: .quantityType(forIdentifier: .activeEnergyBurned)!)
  async let _rawBasalEnergyBurned = queryQuantities(type: .quantityType(forIdentifier: .basalEnergyBurned)!)
  async let _rawStepCount = queryQuantities(type: .quantityType(forIdentifier: .stepCount)!)
  async let _rawFlightsClimbed = queryQuantities(type: .quantityType(forIdentifier: .flightsClimbed)!)
  async let _rawDistanceWalkingRunning = queryQuantities(type: .quantityType(forIdentifier: .distanceWalkingRunning)!)
  async let _rawVo2Max = queryQuantities(type: .quantityType(forIdentifier: .vo2Max)!)

  let rawActiveEnergyBurned = try await _rawActiveEnergyBurned
  let rawBasalEnergyBurned = try await _rawBasalEnergyBurned
  let rawStepCount = try await _rawStepCount
  let rawFlightsClimbed = try await _rawFlightsClimbed
  let rawDistanceWalkingRunning = try await _rawDistanceWalkingRunning
  let rawVo2Max = try await _rawVo2Max

  anchors.appendOptional(rawActiveEnergyBurned.1)
  anchors.appendOptional(rawBasalEnergyBurned.1)
  anchors.appendOptional(rawStepCount.1)
  anchors.appendOptional(rawFlightsClimbed.1)
  anchors.appendOptional(rawDistanceWalkingRunning.1)
  anchors.appendOptional(rawVo2Max.1)

  async let _hourlyActiveEnergyBurned = queryHourlyStatistics(
    type: .quantityType(forIdentifier: .activeEnergyBurned)!,
    discovered: rawActiveEnergyBurned.quantities
  )
  async let _hourlyBasalEnergyBurned = queryHourlyStatistics(
    type: .quantityType(forIdentifier: .basalEnergyBurned)!,
    discovered: rawBasalEnergyBurned.quantities
  )
  async let _hourlyStepCount = queryHourlyStatistics(
    type: .quantityType(forIdentifier: .stepCount)!,
    discovered: rawStepCount.quantities
  )
  async let _hourlyFlightsClimbed = queryHourlyStatistics(
    type: .quantityType(forIdentifier: .flightsClimbed)!,
    discovered: rawFlightsClimbed.quantities
  )
  async let _hourlyDistanceWalkingRunning = queryHourlyStatistics(
    type: .quantityType(forIdentifier: .distanceWalkingRunning)!,
    discovered: rawDistanceWalkingRunning.quantities
  )

  let hourlyActiveEnergyBurned = try await _hourlyActiveEnergyBurned
  let hourlyBasalEnergyBurned = try await _hourlyBasalEnergyBurned
  let hourlyStepCount = try await _hourlyStepCount
  let hourlyFlightsClimbed = try await _hourlyFlightsClimbed
  let hourlyDistanceWalkingRunning = try await _hourlyDistanceWalkingRunning


  // - Day summaries

  // Find the minimum start date.
  let daySummaryStartDate: Date? = [
    hourlyActiveEnergyBurned.first?.startDate,
    hourlyBasalEnergyBurned.first?.startDate,
    hourlyStepCount.first?.startDate,
    hourlyFlightsClimbed.first?.startDate,
    hourlyDistanceWalkingRunning.first?.startDate,
  ].compactMap { $0 }.min()

  let daySummaryEndDate: Date? = [
    hourlyActiveEnergyBurned.first?.endDate,
    hourlyBasalEnergyBurned.first?.endDate,
    hourlyStepCount.first?.endDate,
    hourlyFlightsClimbed.first?.endDate,
    hourlyDistanceWalkingRunning.first?.endDate,
  ].compactMap { $0 }.max()

  let daySummaries: [GregorianCalendar.FloatingDate: ActivityPatch.DaySummary]

  if let startDate = daySummaryStartDate {
    daySummaries = try await queryActivityDaySummaries(
      dependencies: dependencies,
      startTime: daySummaryStartDate ?? startDate,
      endTime: daySummaryEndDate ?? endDate,
      in: deviceTimeZoneCalendar
    )
  } else {
    daySummaries = [:]
  }

  var allSamples = ActivityPatch.Activity(
    activeEnergyBurned: hourlyActiveEnergyBurned,
    basalEnergyBurned: hourlyBasalEnergyBurned,
    steps: hourlyStepCount,
    floorsClimbed: hourlyFlightsClimbed,
    distanceWalkingRunning: hourlyDistanceWalkingRunning,
    vo2Max: rawVo2Max.quantities
  )

  if options.perDeviceActivityTS {
    allSamples.activeEnergyBurned += rawActiveEnergyBurned.quantities
    allSamples.basalEnergyBurned += rawBasalEnergyBurned.quantities
    allSamples.steps += rawStepCount.quantities
    allSamples.floorsClimbed += rawFlightsClimbed.quantities
    allSamples.distanceWalkingRunning += rawDistanceWalkingRunning.quantities
  }

  let patch = activityPatchGroupedByDay(summaries: daySummaries, samples: allSamples, in: deviceTimeZoneCalendar)
  
  return (patch, anchors: anchors)
}

func handleWorkouts(
  healthKitStore: HKHealthStore,
  vitalStorage: VitalHealthKitStorage,
  startDate: Date,
  endDate: Date,
  options: ReadOptions
) async throws -> (workoutPatch: WorkoutPatch, anchors: [StoredAnchor]) {
  
  var anchors: [StoredAnchor] = []
  
  let payload = try await anchoredQuery(
    healthKitStore: healthKitStore,
    vitalStorage: vitalStorage,
    type: .workoutType(),
    limit: AnchoredQueryChunkSize.workout,
    startDate: startDate,
    endDate: endDate
  )
  
  anchors.appendOptional(payload.anchor)

  let knownAge: Int?
  do {
    let dateOfBirth = try healthKitStore.patched_dateOfBirthComponents()
    knownAge = dateOfBirth.flatMap { dob in
      vitalCalendar.dateComponents(
        [.year],
        from: dob,
        to: vitalCalendar.dateComponents(in: .current, from: Date())
      ).year
    }
  } catch _ {
    knownAge = nil
  }
  let zoneMaxHr = Double(220 - (knownAge ?? 30))

  var copies: [WorkoutPatch.Workout] = []

  for workout in payload.sample {

    let workout = workout as! HKWorkout
    var patch = WorkoutPatch.Workout(workout)

    let fromSameSourceRevision = [NSPredicate(format: "%K == %@", HKPredicateKeyPathSourceRevision, workout.sourceRevision)]
    let fromSameDevice = workout.device.map { [NSPredicate(format: "%K == %@", HKPredicateKeyPathDevice, $0)] } ?? []

    let queryInterval = workout.startDate ..< workout.endDate
    let predicates = Predicates([
      // sample has same HKSourceRevision **OR** sample has same HKDevice
      NSCompoundPredicate(orPredicateWithSubpredicates: fromSameSourceRevision + fromSameDevice)
    ])

    func computeStatistics(_ patch: inout WorkoutPatch.Workout) async throws {
      let samples = try await querySingle(
        healthKitStore,
        type: .quantityType(forIdentifier: .heartRate)!,
        startDate: queryInterval.lowerBound,
        endDate: queryInterval.upperBound,
        extraPredicates: predicates
      )

      guard samples.count >= 2 else {
        return
      }

      let unit = HKUnit.count().unitDivided(by: .minute())
      let timestamps = samples.map { $0.startDate.timeIntervalSinceReferenceDate }
      let durations = vDSP.subtract(timestamps.dropFirst(), timestamps.dropLast())
      let values = samples.map { unsafeDowncast($0, to: HKQuantitySample.self).quantity.doubleValue(for: unit) }.dropLast()
      precondition(durations.count == values.count)

      let zone1Range = 0.0 ..< zoneMaxHr * 0.5
      let zone2Range = 0.5 ..< zoneMaxHr * 0.6
      let zone3Range = 0.6 ..< zoneMaxHr * 0.7
      let zone4Range = 0.7 ..< zoneMaxHr * 0.8
      let zone5Range = 0.8 ..< zoneMaxHr * 0.9
      let zone6Range = 0.9 ..< zoneMaxHr

      var zones = (0.0, 0.0, 0.0, 0.0, 0.0, 0.0)
      var minHr = Double.greatestFiniteMagnitude
      var maxHr = Double.leastNormalMagnitude
      var averageHr = 0.0

      durations.withUnsafeBufferPointer { durations in
        values.withUnsafeBufferPointer { values in
          for i in 0 ..< durations.count {
            let value = values[i]
            minHr = min(minHr, value)
            maxHr = max(maxHr, value)
            averageHr += value

            switch value {
            case zone1Range:
              zones.0 += durations[i]
            case zone2Range:
              zones.1 += durations[i]
            case zone3Range:
              zones.2 += durations[i]
            case zone4Range:
              zones.3 += durations[i]
            case zone5Range:
              zones.4 += durations[i]
            case zone6Range:
              zones.5 += durations[i]
            default:
              continue
            }
          }
        }
      }

      averageHr = averageHr / Double(durations.count)

      patch.heartRateMaximum = Int(maxHr)
      patch.heartRateMinimum = Int(minHr)
      patch.heartRateMean = Int(averageHr)
      patch.heartRateZone1 = Int(zones.0)
      patch.heartRateZone2 = Int(zones.1)
      patch.heartRateZone3 = Int(zones.2)
      patch.heartRateZone4 = Int(zones.3)
      patch.heartRateZone5 = Int(zones.4)
      patch.heartRateZone6 = Int(zones.5)
    }

    try await computeStatistics(&patch)

    if options.embedTimeseries {
      patch.heartRate = try await querySample(
        healthKitStore: healthKitStore,
        type: .quantityType(forIdentifier: .heartRate)!,
        startDate: workout.startDate,
        endDate: workout.endDate,
        extraPredicates: predicates.wrapped
      )
      .compactMap(LocalQuantitySample.init)

      patch.respiratoryRate = try await querySample(
        healthKitStore: healthKitStore,
        type: .quantityType(forIdentifier: .respiratoryRate)!,
        startDate: workout.startDate,
        endDate: workout.endDate,
        extraPredicates: predicates.wrapped
      )
      .compactMap(LocalQuantitySample.init)
    }

    copies.append(patch)
  }
  
  return (.init(workouts: copies), anchors)
}

func handleBloodPressure(
  healthKitStore: HKHealthStore,
  vitalStorage: VitalHealthKitStorage,
  startDate: Date,
  endDate: Date
) async throws -> (bloodPressure: [LocalBloodPressureSample], anchors: [StoredAnchor]) {

  let bloodPressureIdentifier = HKCorrelationType.correlationType(forIdentifier: .bloodPressure)!
  
  let payload = try await anchoredQuery(
    healthKitStore: healthKitStore,
    vitalStorage: vitalStorage,
    type: bloodPressureIdentifier,
    limit: AnchoredQueryChunkSize.timeseries,
    startDate: startDate,
    endDate: endDate
  )
  
  var anchors: [StoredAnchor] = []
  let bloodPressure = payload.sample.compactMap(LocalBloodPressureSample.init)

  anchors.appendOptional(payload.anchor)
  
  return (bloodPressure: bloodPressure, anchors: anchors)
}

func handleTimeSeries(
  type: HKSampleType,
  healthKitStore: HKHealthStore,
  vitalStorage: VitalHealthKitStorage,
  startDate: Date,
  endDate: Date
) async throws -> (samples: [LocalQuantitySample], anchors: [StoredAnchor]) {
  
  let payload = try await anchoredQuery(
    healthKitStore: healthKitStore,
    vitalStorage: vitalStorage,
    type: type,
    limit: AnchoredQueryChunkSize.timeseries,
    startDate: startDate,
    endDate: endDate
  )
  
  var anchors: [StoredAnchor] = []
  let samples: [LocalQuantitySample] = payload.sample.compactMap(LocalQuantitySample.init)
  
  anchors.appendOptional(payload.anchor)
  
  return (samples,anchors)
}


private func anchoredQuery(
  healthKitStore: HKHealthStore,
  vitalStorage: VitalHealthKitStorage,
  type: HKSampleType,
  limit: Int,
  startDate: Date? = nil,
  endDate: Date? = nil,
  extraPredicate: NSPredicate? = nil
) async throws -> (sample: [HKSample], anchor: StoredAnchor?) {

  let shortID = "Query,\(type.shortenedIdentifier)"

  return try await withCheckedThrowingContinuation { continuation in
    let currentAnchor = vitalStorage.read(key: String(describing: type.self))?.anchor

    let handler: AnchorQueryHandler = { (query, samples, deletedObject, newAnchor, error) in
      healthKitStore.stop(query)
      
      if let error = error {
        if let error = error as? HKError {
          switch error.code {
          case .errorAuthorizationNotDetermined, .errorAuthorizationDenied, .errorNoData:
            let storedAnchor = StoredAnchor(
              key: String(describing: type),
              anchor: newAnchor,
              date: Date(),
              vitalAnchors: nil
            )

            VitalLogger.healthKit.info("no data or no permission; anchor = \(newAnchor?.description ?? "nil")", source: shortID)
            continuation.resume(with: .success(([], storedAnchor)))
            return

          default:
            VitalLogger.healthKit.info("HealthKit error = \(error.code)", source: shortID)
            continuation.resume(with: .failure(error))
            return
          }
        } else {
          VitalLogger.healthKit.info("error = \(error)", source: shortID)
          continuation.resume(with: .failure(error))
          return
        }
      }

      let samples = samples ?? []
      let anchorToStore = StoredAnchor(
        key: String(describing: type),
        anchor: newAnchor,
        date: Date(),
        vitalAnchors: nil,
        hasMore: !samples.isEmpty && currentAnchor != newAnchor
      )

      VitalLogger.healthKit.info("found \(samples.count) new, \(anchorToStore.hasMore ? "hasMore" : "noMore")", source: shortID)

      continuation.resume(with: .success((samples, anchorToStore)))
    }
    
    var predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: [])
    
    if let extraPredicate = extraPredicate {
      predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [predicate, extraPredicate])
    }

    let query = HKAnchoredObjectQuery(
      type: type,
      predicate: predicate,
      anchor: currentAnchor,
      limit: limit,
      resultsHandler: handler
    )

    VitalLogger.healthKit.info("will look \(startDate?.description ?? "nil") ..< \(endDate?.description ?? "nil")", source: shortID)
    VitalLogger.healthKit.info("with anchor: \(currentAnchor?.description ?? "nil")", source: shortID)

    healthKitStore.execute(query)
  }
}

@HealthKitActor
func queryMulti(
  healthKitStore: HKHealthStore,
  vitalStorage: VitalHealthKitStorage,
  types: Set<HKSampleType>,
  limit: Int = HKObjectQueryNoLimit,
  startDate: Date? = nil,
  endDate: Date? = nil,
  extraPredicates: Predicates = Predicates([])
) async throws -> [HKSampleType: [HKSample]] {
  guard #available(iOS 15.0, *) else {
    return try await withThrowingTaskGroup(of: (key: HKSampleType, samples: [HKSample]).self) { group in
      for type in types {
        group.addTask { @HealthKitActor in
          let samples = try await querySingle(
            healthKitStore,
            type: type,
            limit: limit,
            startDate: startDate,
            endDate: endDate,
            extraPredicates: extraPredicates
          )

          return (type, samples)
        }
      }

      return try await group.reduce(into: [:]) { result, entry in
        result[entry.key] = entry.samples
      }
    }
  }

  // iOS 15+: Single query to match multiple HKSampleTypes

  return try await withCheckedThrowingContinuation { continuation in

    let handler: (HKSampleQuery, [HKSample]?, Error?) -> Void = { (query, samples, error) in
      healthKitStore.stop(query)

      if let error = error {
        if let error = error as? HKError {
          switch error.code {
          case .errorAuthorizationNotDetermined, .errorAuthorizationDenied, .errorNoData:
            VitalLogger.healthKit.info("no data or no permission. \(error)", source: "QueryMulti")
            continuation.resume(with: .success([:]))
            return

          default:
            VitalLogger.healthKit.info("error[\(error.code)] = \(error)", source: "QueryMulti")
            continuation.resume(with: .failure(error))
            return
          }
        } else {
          VitalLogger.healthKit.info("error = \(error)", source: "QueryMulti")
          continuation.resume(with: .failure(error))
          return
        }
      }

      let samples = Dictionary.init(grouping: samples ?? [], by: \.sampleType)
      continuation.resume(with: .success(samples))
    }

    var predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: [])

    if !extraPredicates.wrapped.isEmpty {
      predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [predicate] + extraPredicates.wrapped)
    }

    let query = HKSampleQuery(
      queryDescriptors: types.map { type in
        HKQueryDescriptor(sampleType: type, predicate: predicate)
      },
      limit: limit != HKObjectQueryNoLimit ? limit * types.count : HKObjectQueryNoLimit,
      sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)],
      resultsHandler: handler
    )

    healthKitStore.execute(query)
  }
}

@HealthKitActor
private func querySingle(
  _ healthKitStore: HKHealthStore,
  type: HKSampleType,
  limit: Int = HKObjectQueryNoLimit,
  startDate: Date? = nil,
  endDate: Date? = nil,
  extraPredicates: Predicates = Predicates([])
) async throws -> [HKSample] {
  return try await withCheckedThrowingContinuation { continuation in
    let handler: (HKSampleQuery, [HKSample]?, Error?) -> Void = { (query, samples, error) in
      healthKitStore.stop(query)

      if let error = error {
        if let error = error as? HKError {
          switch error.code {
          case .errorAuthorizationNotDetermined, .errorAuthorizationDenied, .errorNoData:
            VitalLogger.healthKit.info("no data or no permission for \(type.shortenedIdentifier)", source: "QuerySingle")
            continuation.resume(with: .success([]))
            return

          default:
            VitalLogger.healthKit.info("\(type.shortenedIdentifier) error = \(error.code)", source: "QuerySingle")
            continuation.resume(with: .failure(error))
            return
          }
        } else {
          VitalLogger.healthKit.info("\(type.shortenedIdentifier) error = \(error)", source: "QuerySingle")
          continuation.resume(with: .failure(error))
          return
        }
      }

      continuation.resume(with: .success(samples ?? []))
    }

    var predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: [])

    if !extraPredicates.wrapped.isEmpty {
      predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [predicate] + extraPredicates.wrapped)
    }

    let query = HKSampleQuery(
      sampleType: type,
      predicate: predicate,
      limit: limit,
      sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)],
      resultsHandler: handler
    )

    healthKitStore.execute(query)
  }
}


func calculateIdsForAnchorsPopulation(
  vitalStatistics: [VitalStatistics],
  date: Date
) -> [VitalAnchor] {
  let cleanedStatistics = vitalStatistics.filter { statistic in
    isValidStatistic(statistic)
  }
  
  /// Generate new anchors based on the read statistics values
  let newAnchors = cleanedStatistics.compactMap { statistics in
    generateIdForAnchor(statistics).map(VitalAnchor.init(id:))
  }
  
  let value = Set(newAnchors)
  return Array(value)
}

func calculateIdsForAnchorsAndData(
  vitalStatistics: [VitalStatistics],
  existingAnchors: [VitalAnchor],
  key: String,
  date: Date
) -> ([VitalStatistics], StoredAnchor) {
  
  /// Clean-up the values with zero
  let cleanedStatistics = vitalStatistics.filter { statistic in
    isValidStatistic(statistic)
  }
  
  /// Generate new anchors based on the read statistics values
  let newAnchors = cleanedStatistics.compactMap { statistics in
    generateIdForAnchor(statistics).map(VitalAnchor.init(id:))
  }
    
  /// There's a difference between what we want to send to the server, versus what we want to store
  /// The ones to send, is the delta between the new versus the existing.
  let toSendIds = anchorsToSend(old: existingAnchors, new: newAnchors)
  
  /// The ones we want store is a union of all ids.
  let toStoreIds = anchorsToStore(old: existingAnchors, new: newAnchors)
  
  /// We can now filter the statistics that match the ids we want to send
  let dataToSend: [VitalStatistics] = cleanedStatistics.filter { statistics in
    guard let id = generateIdForAnchor(statistics) else {
      return false
    }
    
    return toSendIds.map(\.id).contains(id)
  }
  
  let storedAnchor = StoredAnchor(
    key: key,
    anchor: nil,
    date: date,
    vitalAnchors: toStoreIds
  )

  return (dataToSend, storedAnchor)
}


/// TODO: To be Removed
private func populateAnchorsForStatisticalQuery(
  dependency: StatisticsQueryDependencies,
  type: HKQuantityType,
  statisticsQueryStartDate: Date
) async throws -> [VitalAnchor] {
    
  let startDate = vitalCalendar.date(byAdding: .day, value: -21, to: statisticsQueryStartDate)!.dayStart
  let endDate = statisticsQueryStartDate.beginningHour

  let statistics = try await dependency.executeStatisticalQuery(type, startDate ..< endDate, .hourly, nil)
  let newAnchors = calculateIdsForAnchorsPopulation(
    vitalStatistics: statistics,
    date: endDate
  )

  return newAnchors
}

/// We compute one summary per quantity type for the calendar day in the
/// **CURRENT DEVICE TIME ZONE**. After all, a (floating) day cannot be
/// projected into UTC time without a time zone, and the user intuition is
/// to see numbers and time that align to their perception of time.
///
/// (where the device time zone is the closest approximation)
///
/// This is different from the typical hourly timeseries samples gathering process, which
/// works with `HKStatisticalCollectionQuery` solely in UTC time (`vitalCalendar`).
/// Hour granularity is time zone agnostic, and the resulting hourly samples can be reinterpreted into all
/// time zones pretty easily and consistently.
func queryActivityDaySummaries(
  dependencies: StatisticsQueryDependencies,
  startTime: Date,
  endTime: Date,
  in calendar: GregorianCalendar
) async throws -> [GregorianCalendar.FloatingDate: ActivityPatch.DaySummary] {
  // System wall time can go backwards. Cap the start time just in case.
  let datesToCompute = calendar.floatingDate(of: min(startTime, endTime))
    ... calendar.floatingDate(of: endTime)
  let queryInterval = calendar.timeRange(of: datesToCompute)

  VitalLogger.healthKit.info("lastComputed = \(startTime) now = \(endTime)", source: "DaySummary")
  VitalLogger.healthKit.info("recomputing \(queryInterval.lowerBound) ..< \(queryInterval.upperBound)", source: "DaySummary")

  async let _activeEnergyBurnedSum = dependencies.executeStatisticalQuery(
    HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!,
    queryInterval,
    .daily,
    nil
  )
  async let _basalEnergyBurnedSum = dependencies.executeStatisticalQuery(
    HKQuantityType.quantityType(forIdentifier: .basalEnergyBurned)!,
    queryInterval,
    .daily,
    nil
  )
  async let _stepsSum = dependencies.executeStatisticalQuery(
    HKQuantityType.quantityType(forIdentifier: .stepCount)!,
    queryInterval,
    .daily,
    nil
  )
  async let _floorsClimbedSum = dependencies.executeStatisticalQuery(
    HKQuantityType.quantityType(forIdentifier: .flightsClimbed)!,
    queryInterval,
    .daily,
    nil
  )
  async let _distanceWalkingRunningSum = dependencies.executeStatisticalQuery(
    HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)!,
    queryInterval,
    .daily,
    nil
  )
  async let _maxHeartRate = dependencies.executeStatisticalQuery(
    HKQuantityType.quantityType(forIdentifier: .heartRate)!,
    queryInterval,
    .daily,
    .discreteMax
  )

  async let _minHeartRate = dependencies.executeStatisticalQuery(
    HKQuantityType.quantityType(forIdentifier: .heartRate)!,
    queryInterval,
    .daily,
    .discreteMin
  )

  async let _averageHeartRate = dependencies.executeStatisticalQuery(
    HKQuantityType.quantityType(forIdentifier: .heartRate)!,
    queryInterval,
    .daily,
    .discreteAverage
  )

  async let _restingHeartRate = dependencies.executeStatisticalQuery(
    HKQuantityType.quantityType(forIdentifier: .restingHeartRate)!,
    queryInterval,
    .daily,
    nil
  )

  async let _appleExerciseTime = dependencies.executeStatisticalQuery(
    HKQuantityType.quantityType(forIdentifier: .appleExerciseTime)!,
    queryInterval,
    .daily,
    nil
  )

  func keyedByDate(_ statistics: [VitalStatistics]) -> [GregorianCalendar.FloatingDate: VitalStatistics] {
    Dictionary(grouping: statistics) { calendar.floatingDate(of: $0.startDate) }
      .mapValues { statistics in
        assert(statistics.count == 1, "Expected statistical query to produce one stat per day. Found multiple stats per day.")
        return statistics[0]
      }
  }

  let activeEnergyBurnedSum = keyedByDate(try await _activeEnergyBurnedSum)
  let basalEnergyBurnedSum = keyedByDate(try await _basalEnergyBurnedSum)
  let stepsSum = keyedByDate(try await _stepsSum)
  let floorsClimbedSum = keyedByDate(try await _floorsClimbedSum)
  let distanceWalkingRunningSum = keyedByDate(try await _distanceWalkingRunningSum)
  let maxHeartRate = keyedByDate(try await _maxHeartRate)
  let minHeartRate = keyedByDate(try await _minHeartRate)
  let averageHeartRate = keyedByDate(try await _averageHeartRate)
  let restingHeartRate = keyedByDate(try await _restingHeartRate)
  let appleExerciseTime = keyedByDate(try await _appleExerciseTime)

  var result = [GregorianCalendar.FloatingDate: ActivityPatch.DaySummary]()
  for date in calendar.enumerate(datesToCompute) {
    // Round down all sums to match Apple Health app behaviour.
    result[date] = ActivityPatch.DaySummary(
      calendarDate: date,
      activeEnergyBurnedSum: activeEnergyBurnedSum[date]?.value.rounded(.down),
      basalEnergyBurnedSum: basalEnergyBurnedSum[date]?.value.rounded(.down),
      stepsSum: (stepsSum[date]?.value.rounded(.down)).map(Int.init),
      floorsClimbedSum: (floorsClimbedSum[date]?.value.rounded(.down)).map(Int.init),
      distanceWalkingRunningSum: distanceWalkingRunningSum[date]?.value.rounded(.down),
      maxHeartRate: (maxHeartRate[date]?.value.rounded(.down)).map(Int.init),
      minHeartRate: (minHeartRate[date]?.value.rounded(.down)).map(Int.init),
      avgHeartRate: (averageHeartRate[date]?.value.rounded(.down)).map(Int.init),
      restingHeartRate: (restingHeartRate[date]?.value.rounded(.down)).map(Int.init),
      exerciseTime: (appleExerciseTime[date]?.value.rounded(.down)).map(Int.init)
    )
  }

  return result
}

func querySample(
  healthKitStore: HKHealthStore,
  type: HKSampleType,
  limit: Int = HKObjectQueryNoLimit,
  startDate: Date? = nil,
  endDate: Date? = nil,
  ascending: Bool = true,
  extraPredicates: [NSPredicate] = [],
  options: HKQueryOptions = [.strictStartDate]
) async throws -> [HKSample] {
  
  return try await withCheckedThrowingContinuation { continuation in
    
    let handler: SampleQueryHandler = { (query, samples, error) in
      healthKitStore.stop(query)
      
      if let error = error {
        continuation.resume(with: .failure(error))
        return
      }
      
      continuation.resume(with: .success(samples ?? []))
    }
    
    var predicate = HKQuery.predicateForSamples(
      withStart: startDate,
      end: endDate,
      options: options
    )

    if !extraPredicates.isEmpty {
      predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [predicate] + extraPredicates)
    }

    let sort = [
      NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: ascending)
    ]
    
    let query = HKSampleQuery(
      sampleType: type,
      predicate: predicate,
      limit: limit,
      sortDescriptors: sort,
      resultsHandler: handler
    )
    
    healthKitStore.execute(query)
  }
}

func mergeSleeps(sleeps: [SleepPatch.Sleep]) -> [SleepPatch.Sleep] {
  
  func compareSleep(
    sleeps: [SleepPatch.Sleep],
    sleep: SleepPatch.Sleep
  ) -> [SleepPatch.Sleep] {
    
    for (index, value) in sleeps.enumerated() {
      
      if
        (value.startDate ... value.endDate).overlaps(sleep.startDate ... sleep.endDate) &&
          value.sourceBundle == sleep.sourceBundle
      {
        
        var copySleep = sleep
        copySleep.startDate = min(value.startDate, copySleep.startDate)
        copySleep.endDate = max(value.endDate, copySleep.endDate)
        
        var copySleeps = sleeps
        copySleeps.remove(at: index)
        
        return compareSleep(sleeps: copySleeps, sleep: copySleep)
      }
    }
    
    return sleeps + [sleep]
  }
  
  let sanityCheck = sleeps.filter {
    $0.endDate >= $0.startDate
  }
  
  return sanityCheck.reduce(into: []) { acc, sleep in
    acc = compareSleep(sleeps: acc, sleep: sleep)
  }
}

func stitchedSleeps(sleeps: [SleepPatch.Sleep], sourceType: SourceType) -> [SleepPatch.Sleep] {
  let allowedGapInMinutes: Double
  switch sourceType {
  case .phone:
    /// iPhone sleep has only inBed samples, while gaps are implying "awake".
    /// So we need a more generous time gap allowance when stitching sleeps.
    allowedGapInMinutes = 120
  default:
    allowedGapInMinutes = 30
  }

  return sleeps.reduce(into: []) { acc, newSleep in
    
    guard var lastValue = acc.last else {
      acc = [newSleep]
      return
    }
    
    guard lastValue.sourceBundle == newSleep.sourceBundle else {
      acc = acc + [newSleep]
      return
    }
    
    /// A) `newSleep` happens after `lastValue`
    ///
    /// |____________|   <->  |____________|
    ///    lastValue     X min     newSleep
    if newSleep.startDate > lastValue.endDate  {
      
      /// It happens in less than X minutes
      if isDuration(lastValue.endDate, newSleep.startDate, longerThan: allowedGapInMinutes * 60) == false {
        let newAcc = acc.dropLast()
        lastValue.endDate = newSleep.endDate
        acc = newAcc + [lastValue]
        return
      }
    }
    
    /// B) `lastValue` happens after `newSleep`
    ///
    /// |____________|  <->  |____________|
    ///    newSleep     X min     lastValue
    if lastValue.startDate > newSleep.endDate  {
      let longerThanAllowed = isDuration(newSleep.endDate, lastValue.startDate, longerThan: allowedGapInMinutes * 60)
      
      /// It happens in less than X minutes
      if longerThanAllowed == false {
        let newAcc = acc.dropLast()
        lastValue.startDate = newSleep.startDate
        acc = newAcc + [lastValue]
        return
      }
    }
    
    /// C) `lastValue` overlaps `newSleep` (and vice-versa)
    ///
    /// |____________|
    ///    newSleep
    ///       |____________|
    ///         lastValue
    
    if (lastValue.startDate ... lastValue.endDate).overlaps(newSleep.startDate ... newSleep.endDate) {
      let newAcc = acc.dropLast()
      
      lastValue.startDate = min(lastValue.startDate, newSleep.startDate)
      lastValue.endDate = max(lastValue.endDate, newSleep.endDate)
      
      acc = newAcc + [lastValue]
      return
    }
    
    /// There's no overlap, or the difference is more than 30 minutes.
    /// It's likely a completely new entry
    acc = acc + [newSleep]
  }
}

private func filterForWatch(samples: [HKSample]) -> [HKSample] {
  return samples.filter { sample in
    let bundleIdentifier = sample.sourceRevision.source.bundleIdentifier
    
    if bundleIdentifier.contains(DataSource.appleHealthKit.rawValue) {

      /// Data generated from a watch can look like this `Optional("Watch4,4")`
      if let productType = sample.sourceRevision.productType {
        return productType.lowercased().contains("watch")
      } else {
        /// We don't know what this is.
        return false
      }
      
    } else {
      /// This sample was made by something else besides com.apple.healthkit
      /// So we allow it
      return true
    }
  }
}

private func filter(samples: [HKSample], by dataSources: [DataSource]) -> [HKSample] {
  
  return samples.filter { sample in
    let identifier = sample.sourceRevision.source.bundleIdentifier

    if
      let wasUserEntered = sample.metadata?[HKMetadataKeyWasUserEntered] as? Bool,
      wasUserEntered == true {
      /// If it's manually entered, allow the sample
      return true
    }

    // It wasn't user entered, so let's match it against the allowed bundle identifiers
    for dataSource in dataSources {
      if identifier.contains(dataSource.rawValue) {
        return true
      }
    }
    
    return false
  }
}

private func filter(samples: [HKSample], on productType: String, sourceBundle: String) -> [HKSample] {
  return samples.filter { sample in
    return sample.sourceRevision.productType == productType &&
    sample.sourceRevision.source.bundleIdentifier == sourceBundle
  }
}

private func isDuration(_ date1: Date, _ date2: Date, longerThan seconds: TimeInterval) -> Bool {
  let diff = abs(date1.timeIntervalSinceReferenceDate - date2.timeIntervalSinceReferenceDate)
  return diff > seconds
}

private func orderByDate(_ values: [LocalQuantitySample]) -> [LocalQuantitySample] {
  return values.sorted { $0.startDate < $1.startDate }
}

func splitPerBundle(_ values: [LocalQuantitySample]) -> [[LocalQuantitySample]] {
  var temp: [String: [LocalQuantitySample]] = ["na": []]
  
  for value in values {
    if let bundle = value.sourceBundle {
      if temp[bundle] != nil {
        var copy = temp[bundle]!
        copy.append(value)
        temp[bundle] = copy
      } else {
        temp[bundle] = [value]
      }
    } else {
      var copy = temp["na"]!
      copy.append(value)
      temp["na"] = copy
    }
  }
  
  var outcome: [[LocalQuantitySample]] = [[]]
  
  for key in temp.keys {
    let samples = temp[key]!
    outcome.append(samples)
  }
  
  return outcome
}

func activityPatchGroupedByDay(
  summaries: [GregorianCalendar.FloatingDate: ActivityPatch.DaySummary],
  samples: ActivityPatch.Activity,
  in calendar: GregorianCalendar
) -> ActivityPatch? {
  func grouped(_ samples: [LocalQuantitySample]) -> [GregorianCalendar.FloatingDate: [LocalQuantitySample]] {
    Dictionary(
     grouping: samples, by: { calendar.floatingDate(of: $0.startDate) }
   )
  }

  let activeEnergyBurned = grouped(samples.activeEnergyBurned)
  let basalEnergyBurned = grouped(samples.basalEnergyBurned)
  let steps = grouped(samples.steps)
  let distanceWalkingRunning = grouped(samples.distanceWalkingRunning)
  let floorsClimbed = grouped(samples.floorsClimbed)
  let vo2Max = grouped(samples.vo2Max)

  // Current assumption: Day summaries must have been computed from the earliest calendar date
  // touched by the samples we've loaded. So `summaries.key` must contain all the dates that have
  // data.
  let activities = summaries
    .filter { $0.value.isNotEmpty }
    .sorted(by: { $0.key < $1.key })
    .map { date, summary in
      ActivityPatch.Activity(
        daySummary: summary,
        activeEnergyBurned: activeEnergyBurned[date] ?? [],
        basalEnergyBurned: basalEnergyBurned[date] ?? [],
        steps: steps[date] ?? [],
        floorsClimbed: floorsClimbed[date] ?? [],
        distanceWalkingRunning: distanceWalkingRunning[date] ?? [],
        vo2Max: vo2Max[date] ?? []
      )
    }

  let patch = ActivityPatch(activities: activities)
  return patch.isNotEmpty ? patch : nil
}

struct SleepGroupKey: Hashable {
  let bundleIdentifier: String
  let productType: String?

  var sourceType: SourceType {
    return .infer(sourceBundle: bundleIdentifier, productType: productType)
  }
}
