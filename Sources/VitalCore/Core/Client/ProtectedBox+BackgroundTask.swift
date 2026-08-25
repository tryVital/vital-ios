import UIKit

extension ProtectedBox where T == UIBackgroundTaskIdentifier {
  public func start(_ name: String, expiration: @escaping () -> Void) {
    _ = startIfAvailable(name, expiration: expiration)
  }

  public func startIfAvailable(_ name: String, expiration: @escaping () -> Void) -> Bool {
    let taskId = UIApplication.shared.beginBackgroundTask(withName: name) { [weak self] in
      expiration()
      self?.endIfNeeded()
    }
    set(value: taskId)
    return taskId != .invalid
  }

  public func endIfNeeded() {
    if let taskId = clean(), taskId != .invalid {
      UIApplication.shared.endBackgroundTask(taskId)
    }
  }
}
