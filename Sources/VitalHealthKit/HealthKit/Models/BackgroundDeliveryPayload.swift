import HealthKit
import VitalCore

struct BackgroundDeliveryPayload {
  let resource: VitalResource
  let completion: () -> Void
}
