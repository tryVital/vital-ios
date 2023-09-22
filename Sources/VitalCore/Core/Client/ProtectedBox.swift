import Foundation

public final class ProtectedBox<T>: @unchecked Sendable {

  private let lock = NSLock()

  private var state: BoxState<T> = .awaiting([])

  /// Get the current value, or `nil` if none has been set.
  public var value: T? {
    switch self.state {
    case let .ready(value):
      return value
    case .awaiting:
      return nil
    }
  }
  
  public init(value: T? = nil) {
    self.state = value.map { .ready($0) } ?? .awaiting([])
  }
  
  deinit {
    switch state {
    case .ready:
      break
    case let .awaiting(continuations):
      if !continuations.isEmpty {
        fatalError("\(continuations.count) dangling continuations in \(Self.self)")
      }
    }
  }
  
  public func isNil() -> Bool {
    return lock.withLock { !self.state.isReady }
  }

  /// Get the current value, or wait until it is set.
  public func get() async -> T {
    return await withCheckedContinuation { continuation in
      lock.withLock {
        switch self.state {
        case let .awaiting(continuations):
          self.state = .awaiting(continuations + [continuation])
        case let .ready(value):
          continuation.resume(returning: value)
        }
      }
    }
  }

  public func set(value: T) {
    let continuationsToCall: [CheckedContinuation<T, Never>] = lock.withLock {
      defer {
        self.state = .ready(value)
      }

      switch self.state {
      case .ready:
        return []
      case let .awaiting(continuations):
        return continuations
      }
    }

    continuationsToCall.forEach { $0.resume(returning: value) }
  }

  @discardableResult
  public func clean() -> T? {
    return lock.withLock {
      switch self.state {
      case let .ready(oldValue):
        self.state = .awaiting([])
        return oldValue

      case let .awaiting(contiunations):
        self.state = .awaiting(contiunations)
        return nil
      }
    }
  }
}

private enum BoxState<T> {
  case ready(T)
  case awaiting([CheckedContinuation<T, Never>])

  var isReady: Bool {
    switch self {
    case .ready:
      return true
    case .awaiting:
      return false
    }
  }
}
