import HealthKit
import Foundation
import VitalCore

func computeWorkoutStream(for workout: HKWorkout, in healthKitStore: HKHealthStore) async throws -> ManualWorkoutStream {
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

  init(_ sample: HKQuantitySample) {
    self.sourceBundle = sample.sourceRevision.source.bundleIdentifier
    self.productType = sample.sourceRevision.productType
  }
}

func groupIntoBulkSamples(_ samples: [HKSample], type: HKSampleType, anchor: Date) -> [BulkQuantitySample] {
  let quantityType = type as! HKQuantityType
  let samples = samples as! [HKQuantitySample]

  let unit = QuantityUnit(.init(rawValue: quantityType.identifier))

  let groups = Dictionary(grouping: samples, by: GroupingKey.init)
  let anchorEpoch = anchor.timeIntervalSince1970

  return groups.map { (key, samples) in
    let metadata = samples.first.map { sampleMetadata($0) }
    return BulkQuantitySample(
      anchor: anchor,
      value: samples.map { $0.quantity.doubleValue(for: unit.healthKitRepresentation) },
      startOffset: samples.map { $0.startDate.timeIntervalSince1970 - anchorEpoch },
      endOffset: samples.map { $0.endDate.timeIntervalSince1970 - anchorEpoch },
      sourceBundle: key.sourceBundle,
      productType: key.productType,
      type: nil,
      metadata: metadata
    )
  }
}
