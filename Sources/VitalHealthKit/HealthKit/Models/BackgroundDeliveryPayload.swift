import HealthKit
import UIKit

struct BackgroundDeliveryPayload: CustomStringConvertible {
  let resources: Set<RemappedVitalResource>
  let completion: (Completion) -> Void
  let appState: UIApplication.State

  var description: String {
    "\(resources.map(\.wrapped.logDescription).joined(separator: ",")) fg=\(appState != .background)"
  }

  enum Completion {
    case cancelled
    case completed
  }
}
