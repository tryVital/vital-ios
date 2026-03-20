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

func computeWorkoutStream(for workout: HKWorkout, in healthKitStore: HKHealthStore) async throws -> ManualWorkoutStream {
  let shortID = "WorkoutStream"
  let workoutID = workout.uuid
  VitalLogger.healthKit.info("\(workoutID) begin", source: shortID)
  defer {
    VitalLogger.healthKit.info("\(workoutID) ended", source: shortID)
  }

  var types: Set<HKQuantityType> = [
    .quantityType(forIdentifier: .distanceCycling)!,
    .quantityType(forIdentifier: .distanceSwimming)!,
    .quantityType(forIdentifier: .distanceWheelchair)!,
    .quantityType(forIdentifier: .distanceWalkingRunning)!,
    .quantityType(forIdentifier: .distanceDownhillSnowSports)!,
    .quantityType(forIdentifier: .swimmingStrokeCount)!,
  ]

  if #available(iOS 18, *) {
    types.formUnion([
      .quantityType(forIdentifier: .distanceRowing)!,
      .quantityType(forIdentifier: .distancePaddleSports)!,
      .quantityType(forIdentifier: .distanceSkatingSports)!,
      .quantityType(forIdentifier: .distanceCrossCountrySkiing)!,
    ])
  }

  let sampleGroups = try await queryMulti(
    healthKitStore: healthKitStore,
    types: types,
    extraPredicates: Predicates([
      HKQuery.predicateForObjects(from: workout)
    ])
  )

  let anchor = workout.startDate
  var components: [ManualWorkoutStream.Component: [BulkQuantitySample]] = [:]

  for (sampleType, samples) in sampleGroups {
    let component: ManualWorkoutStream.Component

    switch sampleType {
    case .quantityType(forIdentifier: .distanceCycling)!:
      component = .distanceCycling
    case .quantityType(forIdentifier: .distanceSwimming)!:
      component = .distanceSwimming
    case .quantityType(forIdentifier: .distanceWheelchair)!:
      component = .distanceWheelchair
    case .quantityType(forIdentifier: .distanceWalkingRunning)!:
      component = .distanceWalkingRunning
    case .quantityType(forIdentifier: .distanceDownhillSnowSports)!:
      component = .distanceDownhillSnowSports
    case .quantityType(forIdentifier: .swimmingStrokeCount)!:
      component = .swimmingStrokeCount

    default:
      if #available(iOS 18, *) {
        switch sampleType {
        case .quantityType(forIdentifier: .distanceRowing)!:
          component = .distanceRowing
        case .quantityType(forIdentifier: .distancePaddleSports)!:
          component = .distancePaddleSports
        case .quantityType(forIdentifier: .distanceSkatingSports)!:
          component = .distanceSkatingSports
        case .quantityType(forIdentifier: .distanceCrossCountrySkiing)!:
          component = .distanceCrossCountrySkiing
        default:
          throw VitalHealthKitClientError.healthKitInvalidState("unrecognized workout stream type: \(sampleType)")
        }
      } else {
        throw VitalHealthKitClientError.healthKitInvalidState("unrecognized workout stream type: \(sampleType)")
      }
    }

    components[component, default: []].append(
      contentsOf: groupIntoBulkSamples(samples, type: sampleType, anchor: anchor)
    )
  }

  return ManualWorkoutStream(components: components)
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
