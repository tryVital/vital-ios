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

  static func current(with tags: SyncContextTag...) -> Set<SyncContextTag> {
    precondition(Thread.isMainThread)
    var tags = Set(tags)

    if UIApplication.shared.applicationState == .background {
      tags.insert(.background)
    } else {
      tags.insert(.foreground)
    }

    if ProcessInfo.processInfo.isLowPowerModeEnabled {
      tags.insert(.lowPowerMode)
    }

    if UIApplication.shared.backgroundRefreshStatus != .available {
      tags.insert(.barUnavailable)
    }

    return tags
  }
}

struct BackgroundDeliveryPayload: CustomStringConvertible {
  let resources: Set<RemappedVitalResource>
  let completion: (Completion) -> Void
  let tags: Set<SyncContextTag>

  var description: String {
    "\(resources.map(\.wrapped.logDescription).joined(separator: ",")) \(tags.map(String.init(describing:)).joined(separator: ","))"
  }

  enum Completion {
    case cancelled
    case completed
  }
}
