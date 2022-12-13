import Foundation

public actor ProtectedBox<T> {
  private var continuations: [CheckedContinuation<T, Never>] = []
  private var value: T?
  
  public init(value: T? = nil) {
    self.value = value
  }
  
  deinit {
    continuations = []
  }
  
  public func isNil() async -> Bool {
    return value == nil
  }
  
  public func get() async -> T {
    if let value = value {
      return value
    } else {
      return await withCheckedContinuation { continuation in
        continuations.append(continuation)
      }
    }
  }
  
  public func set(value: T) async {
    self.value = value
    
    continuations.forEach { continuation in
      continuation.resume(with: .success(value))
    }

    continuations = []
  }
  
  public func clean() {
    self.value = nil
  }
}
