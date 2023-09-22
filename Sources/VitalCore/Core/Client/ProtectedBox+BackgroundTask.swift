import UIKit

extension ProtectedBox where T == UIBackgroundTaskIdentifier {
  public func start(_ name: String, expiration: @escaping () -> Void) {
    let taskId = UIApplication.shared.beginBackgroundTask(withName: name) { [weak self] in
      expiration()
      self?.endIfNeeded()
    }
    set(value: taskId)
  }

  public func endIfNeeded() {
    if let taskId = clean(), taskId != .invalid {
      UIApplication.shared.endBackgroundTask(taskId)
    }
  }
}
