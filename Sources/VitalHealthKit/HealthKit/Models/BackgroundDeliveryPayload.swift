import HealthKit

struct BackgroundDeliveryPayload {
  let sampleTypes: Set<HKSampleType>
  let completion: () -> Void
}
