import Foundation

actor ProtectedBox<T> {
  private var continuations: [CheckedContinuation<T, Never>] = []
  private var value: T?
  
  init(value: T? = nil) {
    self.value = value
  }
  
  deinit {
    continuations = []
  }
  
  func isNil() async -> Bool {
    return value == nil
  }
  
  func get() async -> T {
    if let value = value {
      return value
    } else {
      return await withCheckedContinuation { continuation in
        continuations.append(continuation)
      }
    }
  }
  
  func set(value: T) {
    self.value = value
    
    continuations.forEach { continuation in
      continuation.resume(with: .success(value))
    }
    
    continuations = []
  }
  
  func clean() {
    self.value = nil
  }
}
