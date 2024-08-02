import HealthKit
import UIKit

public enum SyncContextTag: Int, Codable {
  case foreground = 0
  case background = 1
  case healthKit = 2
  case processingTask = 3
  case historicalStage = 4
  case barUnavailable = 5
  case lowPowerMode = 6
  case maintenanceTask = 7
  case manual = 8
  case appLaunching = 9
  case appTerminating = 10
}

struct BackgroundDeliveryPayload: CustomStringConvertible {
  let resources: [RemappedVitalResource]
  let completion: (Completion) -> Void

  var description: String {
    "\(resources.map(\.wrapped.logDescription).joined(separator: ",")))"
  }

  enum Completion {
    case cancelled
    case completed
  }
}
