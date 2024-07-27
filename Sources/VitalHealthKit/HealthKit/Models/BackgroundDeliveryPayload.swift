import HealthKit
import UIKit

public enum SyncTrigger: Int, Codable {
  case foreground = 0
  case backgroundHealthKit = 1
  case backgroundProcessingTask = 2
  case backgroundOther = 3
}

struct BackgroundDeliveryPayload: CustomStringConvertible {
  let resources: Set<RemappedVitalResource>
  let completion: (Completion) -> Void
  let trigger: SyncTrigger

  var description: String {
    "\(resources.map(\.wrapped.logDescription).joined(separator: ",")) \(trigger)"
  }

  enum Completion {
    case cancelled
    case completed
  }
}
