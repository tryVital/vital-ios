import Foundation

actor UserIdBox {
  private var continuations: [CheckedContinuation<UUID, Never>] = []
  private var userId: UUID?
  
  deinit {
    continuations = []
  }
  
  func getUserId() async -> UUID {
    if let value = userId {
      return value
    } else {
      return await withCheckedContinuation { continuation in
        continuations.append(continuation)
      }
    }
  }
  
  func set(userId: UUID) {
    self.userId = userId
    
    continuations.forEach { continuation in
      continuation.resume(with: .success(userId))
    }
    
    continuations = []
  }
  
  func clean() {
    self.userId = nil
  }
}
