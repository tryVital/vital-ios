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

final class CancellationLatch: @unchecked Sendable {
  private let lock = NSLock()
  private var cancellation: (@Sendable () -> Void)?
  private var isCancelled = false

  func install(_ cancellation: @escaping @Sendable () -> Void) {
    let shouldCancel = lock.withLock {
      self.cancellation = cancellation
      return isCancelled
    }

    if shouldCancel {
      cancellation()
    }
  }

  func cancel() {
    let cancellation = lock.withLock {
      guard isCancelled == false else { return nil as (@Sendable () -> Void)? }
      isCancelled = true
      return self.cancellation
    }

    cancellation?()
  }
}

final class CancellationAwareContinuation<Value>: @unchecked Sendable {
  fileprivate typealias Continuation = UnsafeContinuation<Value, any Error>

  private enum State {
    case idle
    case waiting(Continuation)
    case resolved(Swift.Result<Value, any Error>)
    case completed
  }

  private let lock = NSLock()
  private var state: State = .idle

  fileprivate func install(_ continuation: Continuation) -> Bool {
    let result = lock.withLock { () -> Swift.Result<Value, any Error>? in
      switch state {
      case .idle:
        state = .waiting(continuation)
        return nil
      case let .resolved(result):
        state = .completed
        return result
      case .waiting, .completed:
        return .failure(CancellationError())
      }
    }

    if let result {
      continuation.resume(with: result)
      return false
    }
    return true
  }

  func resume(returning value: Value) {
    resolve(.success(value))
  }

  func resume(throwing error: any Error) {
    resolve(.failure(error))
  }

  private func resolve(_ result: Swift.Result<Value, any Error>) {
    let continuation = lock.withLock { () -> Continuation? in
      switch state {
      case .idle:
        state = .resolved(result)
        return nil
      case let .waiting(continuation):
        state = .completed
        return continuation
      case .resolved, .completed:
        return nil
      }
    }

    continuation?.resume(with: result)
  }
}

func withCancellationAwareContinuation<Value>(
  _ operation: @escaping @Sendable (CancellationAwareContinuation<Value>) -> Void
) async throws -> Value {
  let continuation = CancellationAwareContinuation<Value>()

  return try await withTaskCancellationHandler(operation: {
    try Task.checkCancellation()
    return try await withUnsafeThrowingContinuation { unsafeContinuation in
      if continuation.install(unsafeContinuation) {
        operation(continuation)
      }
    }
  }, onCancel: {
    continuation.resume(throwing: CancellationError())
  })
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
  func task(
    priority: TaskPriority = .medium,
    _ action: @Sendable @escaping () async throws -> Void,
    onCancel: (() -> Void)? = nil
  ) -> TaskHandle? {
    let handle: TaskHandle? = lock.withLock {
      guard !isCancelled else { return nil }

      let handle = TaskHandle()
      self.activeTasks.insert(handle)

      handle.wrapped = Task<Void, Never>(priority: priority) {
        do {
          try Task.checkCancellation()
          try await action()
        } catch is CancellationError {
          onCancel?()
        } catch _ {}

        self.lock.withLock {
          _ = self.activeTasks.remove(handle)
        }
      }

      return handle
    }

    if handle == nil {
      onCancel?()
    }

    return handle
  }

  /// A sub-scope that imposes a timeout.
  /// All outstanding subtasks would be cancelled, either when:
  /// 1. the specified timeout is reached; OR
  /// 2. the parent`SupervisorScope` is cancelled.
  func timeoutScope(cancellingAfter timeout: TimeInterval) throws -> SupervisorScope {
    let scope = createChild()

    scope.task { [weak scope] in
      try await Task.sleep(nanoseconds: UInt64(timeout * Double(NSEC_PER_SEC)))
      await scope?.cancel()
    }

    return scope
  }

  func complete() async {
    await closeAndWait(cancel: false)
  }

  func cancel() async {
    await closeAndWait(cancel: true)
  }

  private func closeAndWait(cancel: Bool) async {
    let (tasksToClose, subscopesToClose, parentToUnregister) = lock.withLock {
      isCancelled = true
      let parentToUnregister = parent
      let tasksToClose = activeTasks
      let subscopesToClose = activeSubscopes
      activeTasks = []
      activeSubscopes = []
      parent = nil
      return (tasksToClose, subscopesToClose, parentToUnregister)
    }

    defer {
      parentToUnregister?.unregisterChild(self)
    }

    // Cancel all outstanding tasks, and wait for them to complete.
    await withTaskGroup(of: Void.self) { group in
      for task in tasksToClose {
        group.addTask {
          if let task = task.wrapped {
            if cancel {
              task.cancel()
            }

            // Wait for it to complete, but don't care about the result.
            _ = await task.result
          }
        }
      }

      for subscope in subscopesToClose {
        group.addTask {
          await subscope.closeAndWait(cancel: cancel)
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
