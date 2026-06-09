import HealthKit
import Foundation
import VitalCore

struct HeartRateStatisticSample {
  let timestamp: TimeInterval
  let value: Double
}

struct HeartRateStatisticsSummary {
  let minimum: Double
  let maximum: Double
  let mean: Double
  let zones: (Double, Double, Double, Double, Double, Double)
}

func calculateHeartRateStatistics(
  from samples: [HeartRateStatisticSample],
  zoneMaxHr: Double
) -> HeartRateStatisticsSummary? {
  guard let first = samples.first else {
    return nil
  }

  let zone1Upper = zoneMaxHr * 0.5
  let zone2Upper = zoneMaxHr * 0.6
  let zone3Upper = zoneMaxHr * 0.7
  let zone4Upper = zoneMaxHr * 0.8
  let zone5Upper = zoneMaxHr * 0.9

  var zones = (0.0, 0.0, 0.0, 0.0, 0.0, 0.0)
  var minimum = first.value
  var maximum = first.value
  var total = first.value
  var count = 1
  var previous = first

  for sample in samples.dropFirst() {
    let duration = sample.timestamp - previous.timestamp

    switch previous.value {
    case 0.0..<zone1Upper:
      zones.0 += duration
    case zone1Upper..<zone2Upper:
      zones.1 += duration
    case zone2Upper..<zone3Upper:
      zones.2 += duration
    case zone3Upper..<zone4Upper:
      zones.3 += duration
    case zone4Upper..<zone5Upper:
      zones.4 += duration
    case zone5Upper..<zoneMaxHr:
      zones.5 += duration
    default:
      break
    }

    minimum = min(minimum, sample.value)
    maximum = max(maximum, sample.value)
    total += sample.value
    count += 1
    previous = sample
  }

  guard count >= 2 else {
    return nil
  }

  return HeartRateStatisticsSummary(
    minimum: minimum,
    maximum: maximum,
    mean: total / Double(count),
    zones: zones
  )
}

func computeHeartRateStatistics(
  in queryInterval: Range<Date>,
  predicates: Predicates,
  zoneMaxHr: Double,
  knownAge: Int?,
  workoutID: UUID,
  in healthKitStore: HKHealthStore
) async throws -> ((inout WorkoutPatch.Workout) -> Void)? {

  let shortID = "WorkoutHRStat"
  VitalLogger.healthKit.info("\(workoutID) begin", source: shortID)
  defer {
    VitalLogger.healthKit.info("\(workoutID) ended", source: shortID)
  }

  let samples = try await querySingle(
    healthKitStore,
    type: .quantityType(forIdentifier: .heartRate)!,
    startDate: queryInterval.lowerBound,
    endDate: queryInterval.upperBound,
    extraPredicates: predicates
  )

  guard samples.count >= 2 else {
    return nil
  }

  let unit = HKUnit.count().unitDivided(by: .minute())
  let heartRateSamples = samples.map { sample in
    let quantitySample = unsafeDowncast(sample, to: HKQuantitySample.self)
    return HeartRateStatisticSample(
      timestamp: quantitySample.startDate.timeIntervalSinceReferenceDate,
      value: quantitySample.quantity.doubleValue(for: unit)
    )
  }

  guard let statistics = calculateHeartRateStatistics(from: heartRateSamples, zoneMaxHr: zoneMaxHr) else {
    return nil
  }

  return { patch in
    patch.heartRateMaximum = Int(statistics.maximum)
    patch.heartRateMinimum = Int(statistics.minimum)
    patch.heartRateMean = Int(statistics.mean)
    patch.heartRateZone1 = Int(statistics.zones.0)
    patch.heartRateZone2 = Int(statistics.zones.1)
    patch.heartRateZone3 = Int(statistics.zones.2)
    patch.heartRateZone4 = Int(statistics.zones.3)
    patch.heartRateZone5 = Int(statistics.zones.4)
    patch.heartRateZone6 = Int(statistics.zones.5)
    patch.heartRateZoneMaxHr = zoneMaxHr
    patch.heartRateZoneKnownAge = knownAge
  }
}

let workoutStreamPageLimit = 500
let workoutStreamBoundaryUUIDLimit = 2_000
let workoutStreamQuerySlack: TimeInterval = 5 * 60

func computeWorkoutStream(
  for workout: HKWorkout,
  in healthKitStore: HKHealthStore,
  session: WorkoutStreamStagingSession,
  entries: [(type: HKQuantityType, component: ManualWorkoutStream.Component)],
  concurrencyLimit: Int
) async throws -> ManualWorkoutStream {
  let shortID = "WorkoutStream"
  let workoutID = workout.uuid
  VitalLogger.healthKit.info("\(workoutID) begin", source: shortID)
  defer {
    VitalLogger.healthKit.info("\(workoutID) ended", source: shortID)
  }

  let limit = max(concurrencyLimit, 1)

  try await withThrowingTaskGroup(of: Void.self) { group in
    var iterator = entries.makeIterator()

    func addNext() {
      guard let entry = iterator.next() else {
        return
      }

      group.addTask {
        try await extractWorkoutStreamComponent(
          for: workout,
          entry: entry,
          in: healthKitStore,
          session: session
        )
      }
    }

    for _ in 0..<limit {
      addNext()
    }

    while try await group.next() != nil {
      addNext()
    }
  }

  return try await WorkoutStreamStagingStore.shared.stream(
    session: session,
    workoutID: workoutID,
    allowedComponents: Set(entries.map(\.component))
  )
}

func queryableWorkoutStreamTypes() async throws -> [(type: HKQuantityType, component: ManualWorkoutStream.Component)] {
  var entries: [(type: HKQuantityType, component: ManualWorkoutStream.Component)] = []

  for entry in workoutStreamTypes() {
    let authorizationStatus = try await VitalHealthKitStore.live.authorizationStateForHealthKitTypes([entry.type])[entry.type]
    if authorizationStatus != .notDetermined {
      entries.append(entry)
    }
  }

  return entries
}

func workoutStreamTypes() -> [(type: HKQuantityType, component: ManualWorkoutStream.Component)] {
  var types: [(HKQuantityType, ManualWorkoutStream.Component)] = [
    (.quantityType(forIdentifier: .distanceCycling)!, .distanceCycling),
    (.quantityType(forIdentifier: .distanceSwimming)!, .distanceSwimming),
    (.quantityType(forIdentifier: .distanceWheelchair)!, .distanceWheelchair),
    (.quantityType(forIdentifier: .distanceWalkingRunning)!, .distanceWalkingRunning),
    (.quantityType(forIdentifier: .distanceDownhillSnowSports)!, .distanceDownhillSnowSports),
    (.quantityType(forIdentifier: .swimmingStrokeCount)!, .swimmingStrokeCount),
  ]

  if #available(iOS 18, *) {
    types.append(contentsOf: [
      (.quantityType(forIdentifier: .distanceRowing)!, .distanceRowing),
      (.quantityType(forIdentifier: .distancePaddleSports)!, .distancePaddleSports),
      (.quantityType(forIdentifier: .distanceSkatingSports)!, .distanceSkatingSports),
      (.quantityType(forIdentifier: .distanceCrossCountrySkiing)!, .distanceCrossCountrySkiing),
    ])
  }

  return types
}

func extractWorkoutStreamComponent(
  for workout: HKWorkout,
  entry: (type: HKQuantityType, component: ManualWorkoutStream.Component),
  in healthKitStore: HKHealthStore,
  session: WorkoutStreamStagingSession
) async throws {
  let windowEnd = workout.endDate.addingTimeInterval(workoutStreamQuerySlack)
  var state = try await WorkoutStreamStagingStore.shared.state(
    session: session,
    workoutID: workout.uuid,
    component: entry.component,
    initialCursor: workout.startDate.addingTimeInterval(-workoutStreamQuerySlack),
    windowEnd: windowEnd
  )

  while state.exhausted == false {
    try Task.checkCancellation()

    let cursorIn = Date(timeIntervalSinceReferenceDate: state.cursorStart)
    let samples = try await queryWorkoutStreamSamplePage(
      healthKitStore,
      type: entry.type,
      workout: workout,
      cursorStart: cursorIn,
      windowEnd: windowEnd,
      excluding: Set(state.boundaryUUIDsAtCursor),
      limit: workoutStreamPageLimit
    )

    guard samples.isEmpty == false else {
      state = try await WorkoutStreamStagingStore.shared.markExhausted(
        session: session,
        workoutID: workout.uuid,
        component: entry.component
      )
      continue
    }

    let sortedSamples = samples.sorted(by: workoutStreamSampleOrder)
    guard let cursorOut = sortedSamples.map(\.startDate).max() else {
      state = try await WorkoutStreamStagingStore.shared.markExhausted(
        session: session,
        workoutID: workout.uuid,
        component: entry.component
      )
      continue
    }

    var boundaryUUIDs = sortedSamples
      .filter { $0.startDate == cursorOut }
      .map(\.uuid)

    if cursorOut == cursorIn {
      boundaryUUIDs = Array(Set(boundaryUUIDs).union(state.boundaryUUIDsAtCursor))
      if boundaryUUIDs.count > workoutStreamBoundaryUUIDLimit {
        VitalLogger.healthKit.info(
          "\(workout.uuid) \(entry.component.rawValue) boundary UUID threshold exceeded; marking exhausted",
          source: "WorkoutStream"
        )
        state = try await WorkoutStreamStagingStore.shared.markExhausted(
          session: session,
          workoutID: workout.uuid,
          component: entry.component
        )
        continue
      }
    }

    let bulkSamples = groupIntoBulkSamples(sortedSamples, type: entry.type, anchor: workout.startDate)
    state = try await WorkoutStreamStagingStore.shared.appendPage(
      session: session,
      workoutID: workout.uuid,
      component: entry.component,
      quantityTypeIdentifier: entry.type.identifier,
      cursorIn: cursorIn,
      cursorOut: cursorOut,
      boundaryUUIDsAtCursorOut: boundaryUUIDs.sorted { $0.uuidString < $1.uuidString },
      samples: bulkSamples,
      exhausted: samples.count < workoutStreamPageLimit
    )
  }
}

@HealthKitActor
func queryWorkoutStreamSamplePage(
  _ healthKitStore: HKHealthStore,
  type: HKQuantityType,
  workout: HKWorkout,
  cursorStart: Date,
  windowEnd: Date,
  excluding boundaryUUIDs: Set<UUID>,
  limit: Int
) async throws -> [HKQuantitySample] {
  let shortID = "WorkoutStream,\(type.shortenedIdentifier)"

  let handle = CancellableQueryHandle<[HKQuantitySample]>(timeoutSeconds: 8) { continuation in
    let handler: SampleQueryHandler = { _, samples, error in
      if let error = error {
        handleHealthKitError(
          error: error,
          noDataRepresentation: { [] },
          continuation: continuation,
          source: shortID
        )
        return
      }

      continuation.resume(returning: (samples ?? []).compactMap { $0 as? HKQuantitySample })
    }

    var predicates: [NSPredicate] = [
      HKQuery.predicateForSamples(withStart: cursorStart, end: windowEnd, options: [.strictStartDate]),
      HKQuery.predicateForObjects(from: workout),
    ]

    if boundaryUUIDs.isEmpty == false {
      predicates.append(
        NSCompoundPredicate(
          notPredicateWithSubpredicate: HKQuery.predicateForObjects(with: boundaryUUIDs)
        )
      )
    }

    let query = HKSampleQuery(
      sampleType: type,
      predicate: NSCompoundPredicate(andPredicateWithSubpredicates: predicates),
      limit: limit,
      sortDescriptors: [
        NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true),
        NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: true),
      ],
      resultsHandler: handler
    )

    return query
  }

  return try await handle.execute(in: healthKitStore)
}

func workoutStreamSampleOrder(_ lhs: HKQuantitySample, _ rhs: HKQuantitySample) -> Bool {
  if lhs.startDate != rhs.startDate {
    return lhs.startDate < rhs.startDate
  }
  if lhs.endDate != rhs.endDate {
    return lhs.endDate < rhs.endDate
  }
  return lhs.uuid.uuidString < rhs.uuid.uuidString
}

struct GroupingKey: Hashable {
  let sourceBundle: String?
  let productType: String?
  let metadata: [String: String]?

  init(_ sample: HKQuantitySample) {
    self.sourceBundle = sample.sourceRevision.source.bundleIdentifier
    self.productType = sample.sourceRevision.productType
    self.metadata = sampleMetadata(sample)
  }
}

func groupIntoBulkSamples(_ samples: [HKSample], type: HKSampleType, anchor: Date) -> [BulkQuantitySample] {
  let quantityType = type as! HKQuantityType
  let samples = samples as! [HKQuantitySample]

  let unit = QuantityUnit(.init(rawValue: quantityType.identifier))

  let groups = Dictionary(grouping: samples, by: GroupingKey.init)
  let anchorEpoch = anchor.timeIntervalSince1970

  return groups.map { (key, samples) in
    return BulkQuantitySample(
      anchor: anchor,
      value: samples.map { $0.quantity.doubleValue(for: unit.healthKitRepresentation) },
      startOffset: samples.map { $0.startDate.timeIntervalSince1970 - anchorEpoch },
      endOffset: samples.map { $0.endDate.timeIntervalSince1970 - anchorEpoch },
      sourceBundle: key.sourceBundle,
      productType: key.productType,
      type: nil,
      metadata: key.metadata
    )
  }
}
