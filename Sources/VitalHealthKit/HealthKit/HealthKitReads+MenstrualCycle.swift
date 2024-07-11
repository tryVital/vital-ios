import HealthKit
import VitalCore

func handleMenstrualCycle(
  healthKitStore: HKHealthStore,
  vitalStorage: VitalHealthKitStorage,
  startDate: Date,
  endDate: Date
) async throws -> (menstrualCycles: [LocalMenstrualCycle], anchors: [StoredAnchor]) {

  let menstrualFlow = HKCategoryType.categoryType(forIdentifier: .menstrualFlow)!

  let payload = try await query(
    healthKitStore: healthKitStore,
    vitalStorage: vitalStorage,
    type: menstrualFlow,
    startDate: startDate,
    endDate: endDate
  )

  var anchors: [StoredAnchor] = []
  anchors.appendOptional(payload.anchor)

  return (menstrualCycles: [], anchors: anchors)
}
