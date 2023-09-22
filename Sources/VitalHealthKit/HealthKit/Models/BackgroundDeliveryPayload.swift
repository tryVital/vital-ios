import HealthKit

struct BackgroundDeliveryPayload {
  let sampleTypes: Set<HKSampleType>
  let completion: (Completion) -> Void

  enum Completion {
    case cancelled
    case completed
  }
}
