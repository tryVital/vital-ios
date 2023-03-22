
extension AsyncSequence {
  func throttle<ReducedValue>(
    minimumInterval: UInt64,
    initial: ReducedValue,
    reducer: @Sendable @escaping (inout ReducedValue, Self.Element) -> Void
  ) -> AsyncThrottleSequence<Self, ReducedValue> {
    AsyncThrottleSequence(minimumInterval: minimumInterval, initial: initial, upstream: self, reducer: reducer)
  }
}

struct AsyncThrottleSequence<Upstream: AsyncSequence, ReducedValue>: AsyncSequence {
  typealias Element = ReducedValue

  /// milliseconds
  let minimumInterval: UInt64
  let initial: ReducedValue
  let upstream: Upstream
  let reducer: @Sendable (inout ReducedValue, Upstream.Element) -> Void

  func makeAsyncIterator() -> Iterator {
    Iterator(sequence: self)
  }

  actor Iterator: AsyncIteratorProtocol {
    let sequence: AsyncThrottleSequence<Upstream, ReducedValue>

    var upstreamObserver: Task<Void, Error>?
    var reducedValue: ReducedValue
    var upstreamHasCompleted = false
    var shouldEmitAndReset = false

    init(sequence: AsyncThrottleSequence<Upstream, ReducedValue>) {
      self.sequence = sequence
      self.reducedValue = sequence.initial
    }

    func next() async throws -> ReducedValue? {
      if upstreamObserver == nil {
        upstreamObserver = Task {
          for try await element in sequence.upstream {
            upstreamDidEmit(element)
          }

          self.upstreamHasCompleted = true
        }
      }

      repeat {
        try await Task.sleep(nanoseconds: sequence.minimumInterval * 1000 * 1000) // 100ms

        if shouldEmitAndReset {
          defer { self.reducedValue = sequence.initial }
          return self.reducedValue
        }

        if upstreamHasCompleted {
          return nil
        }
      } while true
    }

    func upstreamDidEmit(_ element: Upstream.Element) {
      sequence.reducer(&self.reducedValue, element)
      shouldEmitAndReset = true
    }
  }
}
