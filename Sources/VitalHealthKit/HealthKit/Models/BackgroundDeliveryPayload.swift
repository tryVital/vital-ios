import HealthKit

struct BackgroundDeliveryPayload {
  let sampleType: HKSampleType
  let completion: () -> Void
}
