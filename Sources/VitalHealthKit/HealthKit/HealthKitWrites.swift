import HealthKit
import VitalCore

func write(
  healthKitStore: HKHealthStore,
  dataInput: DataInput,
  startDate: Date,
  endDate: Date
) async throws -> Void {
#if WriteAPI
  switch dataInput {
    case .mindfulSession:

      let mindfulSession = HKCategorySample(type: .categoryType(forIdentifier: .mindfulSession)!, value: 0, start: startDate, end: endDate)
      try await healthKitStore.save(mindfulSession)

    case .caffeine, .water:
      let quantity = HKQuantity(
        unit: QuantityUnit(.init(rawValue: dataInput.type.identifier)).healthKitRepresentation,
        doubleValue: Double(dataInput.value)
      )

      let sample = HKQuantitySample(
        type: dataInput.type,
        quantity: quantity,
        start: startDate,
        end: endDate
      )

      try await healthKitStore.save(sample)
  }
#else
  throw VitalHealthKitClientError.disabledFeature("WriteAPI")
#endif
}
