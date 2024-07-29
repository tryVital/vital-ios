import Foundation

@globalActor
actor HealthKitActor: GlobalActor {
  nonisolated static let shared = HealthKitActor()
}

final class TaskHandle: Hashable, @unchecked Sendable {
  fileprivate var wrapped: Task<Void, Never>?

  init() {}

  func cancel() {
    wrapped?.cancel()
  }

  static func ==(lhs: TaskHandle, rhs: TaskHandle) -> Bool {
    lhs === rhs
  }

  func hash(into hasher: inout Hasher) {
    hasher.combine(ObjectIdentifier(self))
  }
}

final class SupervisorScope: Hashable, @unchecked Sendable {
  let lock = NSLock()
  private var activeTasks: Set<TaskHandle> = []
  private var activeSubscopes: Set<SupervisorScope> = []
  private var isCancelled: Bool

  private weak var parent: SupervisorScope? = nil

  init(isCancelled: Bool = false) {
    self.isCancelled = isCancelled
  }

  @discardableResult
  func task(_ action: @Sendable @escaping () async throws -> Void) throws -> TaskHandle {
    try lock.withLock {
      guard !isCancelled else { throw CancellationError() }

      let handle = TaskHandle()
      activeTasks.insert(handle)

      handle.wrapped = Task<Void, Never> {
        do {
          try await action()
        } catch _ {}

        activeTasks.remove(handle)
      }

      return handle
    }
  }

  /// A sub-scope that imposes a timeout.
  /// All outstanding subtasks would be cancelled, either when:
  /// 1. the specified timeout is reached; OR
  /// 2. the parent`SupervisorScope` is cancelled.
  func timeoutScope(cancellingAfter timeout: TimeInterval) throws -> SupervisorScope {
    let scope = createChild()

    try scope.task { [weak scope] in
      try await Task.sleep(nanoseconds: UInt64(timeout * Double(NSEC_PER_SEC)))
      await scope?.cancel()
    }

    return scope
  }

  func cancel() async {
    let (tasksToCancel, parentToUnregister) = lock.withLock {
      isCancelled = true
      let parentToUnregister = parent
      let tasksToCancel = activeTasks
      activeTasks = []
      parent = nil
      return (tasksToCancel, parentToUnregister)
    }

    parentToUnregister?.unregisterChild(self)

    guard !tasksToCancel.isEmpty else { return }

    // Cancel all outstanding tasks, and wait for them to complete.
    await withTaskGroup(of: Void.self) { group in
      for task in tasksToCancel {
        group.addTask {
          if let task = task.wrapped {
            task.cancel()
            // Wait for it to complete, but don't care about the result.
            _ = await task.result
          }
        }
      }
    }
  }

  private func createChild() -> SupervisorScope {
    lock.withLock {
      guard !isCancelled else {
        // Already cancelled
        return SupervisorScope(isCancelled: true)
      }

      let child = SupervisorScope()
      child.parent = self
      self.activeSubscopes.insert(child)

      return child
    }
  }

  private func unregisterChild(_ child: SupervisorScope) {
    lock.withLock {
      _ = self.activeSubscopes.remove(child)
    }
  }

  static func ==(lhs: SupervisorScope, rhs: SupervisorScope) -> Bool {
    lhs === rhs
  }

  func hash(into hasher: inout Hasher) {
    hasher.combine(ObjectIdentifier(self))
  }
}
