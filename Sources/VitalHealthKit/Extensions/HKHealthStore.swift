import Foundation
import HealthKit

extension HKHealthStore {
  internal func patched_dateOfBirthComponents() throws -> DateComponents? {
    do {
      return try dateOfBirthComponents()
    } catch let error as NSError {
      guard error.code == 0 && error.domain == "Foundation._GenericObjCError"
        else { throw error }
      return nil
    }
  }

  internal func cancellableExecute<Result>(
    _ createQuery: @Sendable @escaping (CheckedContinuation<Result, Error>) -> HKQuery
  ) async throws -> Result {
    let runner = QueryRunner(in: self, create: createQuery)
    return try await runner.result()
  }
}

private actor QueryRunner<Result> {
  private let store: HKHealthStore
  private let create: (CheckedContinuation<Result, Error>) -> HKQuery
  private var runningQuery: HKQuery?

  init(
    in store: HKHealthStore,
    create: @Sendable @escaping (CheckedContinuation<Result, Error>) -> HKQuery
  ) {
    self.store = store
    self.create = create
  }

  func result() async throws -> Result {
    precondition(runningQuery == nil, "QueryRunner instance should not be reused.")

    return try await withTaskCancellationHandler {
      return try await withCheckedThrowingContinuation { continuation in
        guard Task.isCancelled == false else {
          continuation.resume(throwing: CancellationError())
          return
        }

        let query = create(continuation)
        self.runningQuery = query

        store.execute(query)
      }
    } onCancel: {
      Task { await self.cancel() }
    }
  }

  private func cancel() {
    if let query = runningQuery {
      store.stop(query)
    }
  }
}
