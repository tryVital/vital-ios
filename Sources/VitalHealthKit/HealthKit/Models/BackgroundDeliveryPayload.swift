import HealthKit
import UIKit

struct BackgroundDeliveryPayload {
  let sampleTypes: Set<HKSampleType>
  let completion: (Completion) -> Void
  let appState: UIApplication.State

  enum Completion {
    case cancelled
    case completed
  }
}
