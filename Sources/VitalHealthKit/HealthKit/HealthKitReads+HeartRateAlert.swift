import VitalCore
import HealthKit

enum HeartRateAlertType: String {
  case irregularRhythm = "irregular_rhythm"
  case lowHeartRate = "low_heart_rate"
  case highHeartRate = "high_heart_rate"
}

@HealthKitActor
func handleHeartRateAlerts(
  healthKitStore: HKHealthStore,
  vitalStorage: AnchorStorage,
  instruction: SyncInstruction
) async throws -> (samples: [LocalQuantitySample], anchors: [StoredAnchor]) {

  @Sendable
  func queryAlert(
    _ identifier: HKCategoryTypeIdentifier,
    _ alertType: HeartRateAlertType
  ) async throws -> (sample: [LocalQuantitySample], anchor: StoredAnchor?) {
    return try await anchoredQuery(
      healthKitStore: healthKitStore,
      vitalStorage: vitalStorage,
      type: HKCategoryType.categoryType(forIdentifier: identifier)!,
      sampleClass: HKCategorySample.self,
      unit: (),
      limit: AnchoredQueryChunkSize.timeseries,
      startDate: instruction.query.lowerBound,
      endDate: instruction.query.upperBound,
      transform: { sample, _ in
        LocalQuantitySample(
          value: 1,
          startDate: sample.startDate,
          endDate: sample.endDate,
          sourceBundle: sample.sourceRevision.source.bundleIdentifier,
          productType: sample.sourceRevision.productType,
          unit: .count,
          metadata: ["type": alertType.rawValue]
        )
      }
    )
  }

  return try await withThrowingTaskGroup(
    of: (sample: [LocalQuantitySample], anchor: StoredAnchor?).self
  ) { group in
    group.addTask { try await queryAlert(.irregularHeartRhythmEvent, .irregularRhythm) }
    group.addTask { try await queryAlert(.lowHeartRateEvent, .lowHeartRate) }
    group.addTask { try await queryAlert(.highHeartRateEvent, .highHeartRate) }

    var samples = [LocalQuantitySample]()
    var anchors = [StoredAnchor]()

    for try await (sample, anchor) in group {
      samples.append(contentsOf: sample)
      anchors.appendOptional(anchor)
    }

    return (samples, anchors)
  }

}
