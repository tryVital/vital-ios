import HealthKit
import UIKit
import Foundation

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
  let deadline: DispatchTime
  let completion: (Completion) -> Void

  init(
    resources: [RemappedVitalResource],
    deadline: DispatchTime = backgroundSyncDeadline(),
    completion: @escaping (Completion) -> Void
  ) {
    self.resources = resources
    self.deadline = deadline
    self.completion = completion
  }

  var description: String {
    "\(resources.map(\.wrapped.logDescription).joined(separator: ",")))"
  }

  enum Completion {
    case cancelled
    case completed
  }
}
