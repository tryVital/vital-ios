import XCTest
import BackgroundTasks
import HealthKit
import Foundation
import Dispatch

@testable import VitalHealthKit
@testable import VitalCore

class VitalHealthKitClientTests: XCTestCase {
  
  func testSetupWithoutVitalClient() {
    /// This shouldn't crash if called before VitaClient.configure
    VitalHealthKitClient.configure(
      .init(
        backgroundDeliveryEnabled: true, logsEnabled: true
      )
    )
  }

  func testAskingForPermissionsContinuesWithoutAuthentication() async throws {

    await VitalClient.shared.signOut()
    let value = VitalHealthKitClient(store: .debug)

    _ = value.hasAskedForPermission(resource: .body)
    let status = try await value.permissionStatus(for: [.body])
    XCTAssertTrue(status.keys.contains(.body))

    let permission = await value.ask(readPermissions: [.body], writePermissions: [])

    XCTAssertEqual(permission, PermissionOutcome.success)
  }

  func testOneShotCompletionInvokesCallbackOnlyOnceUnderRace() {
    let counter = LockedCounter()
    let completion = OneShotCompletion<Void> { _ in
      counter.increment()
    }

    DispatchQueue.concurrentPerform(iterations: 64) { _ in
      completion.complete(())
    }

    XCTAssertEqual(counter.value, 1)
  }

  func testBackgroundDeliveryEnablementRetriesOnlyLatestFailedAttempt() {
    let state = BackgroundDeliveryEnablementState()
    let steps = HKQuantityType.quantityType(forIdentifier: .stepCount)!
    let observedSampleTypes: Set<HKSampleType> = [steps]

    let firstAttempt = state.beginAttempt(for: steps)
    XCTAssertTrue(state.record(steps, attemptID: firstAttempt, succeeded: false))
    XCTAssertEqual(state.failures(intersecting: observedSampleTypes), observedSampleTypes)

    let retryAttempt = state.beginAttempt(for: steps)
    XCTAssertTrue(state.record(steps, attemptID: retryAttempt, succeeded: true))
    XCTAssertFalse(state.record(steps, attemptID: firstAttempt, succeeded: false))
    XCTAssertTrue(state.failures(intersecting: observedSampleTypes).isEmpty)
  }

  func testBackgroundDeliveryEnablementResetIgnoresLateCallback() {
    let state = BackgroundDeliveryEnablementState()
    let steps = HKQuantityType.quantityType(forIdentifier: .stepCount)!
    let observedSampleTypes: Set<HKSampleType> = [steps]
    let attempt = state.beginAttempt(for: steps)

    state.reset()

    XCTAssertFalse(state.record(steps, attemptID: attempt, succeeded: false))
    XCTAssertTrue(state.failures(intersecting: observedSampleTypes).isEmpty)
  }

  func testTerminatedBackgroundDeliveryStreamCompletesObserverOnce() {
    let (_, continuation) = AsyncStream<BackgroundDeliveryStage>.makeStream()
    continuation.finish()

    let counter = LockedCounter()
    let observerCompletion = OneShotCompletion<Void> { _ in
      counter.increment()
    }
    let payload = BackgroundDeliveryPayload(
      resources: [],
      completion: { completion in
        if completion == .completed {
          observerCompletion.complete(())
        }
      }
    )

    yieldBackgroundDeliveryPayload(payload, to: continuation)
    payload.completion(.completed)

    XCTAssertEqual(counter.value, 1)
  }

  func testExpiredProcessingTaskCannotReportSuccess() {
    let completed = BackgroundProcessingTaskState()
    completed.markSucceeded()
    XCTAssertTrue(completed.shouldCompleteSuccessfully)

    let expired = BackgroundProcessingTaskState()
    expired.markSucceeded()
    expired.markExpired()
    XCTAssertFalse(expired.shouldCompleteSuccessfully)
  }

  func testProcessingTaskRequestUsesOrdinaryNonChargingPolicy() {
    let now = Date(timeIntervalSince1970: 1_000_000)
    let request = makeProcessingTaskRequest(now: now)

    XCTAssertEqual(
      ObjectIdentifier(type(of: request)),
      ObjectIdentifier(BGProcessingTaskRequest.self)
    )
    XCTAssertEqual(request.identifier, processingTaskIdentifier)
    XCTAssertFalse(request.requiresExternalPower)
    XCTAssertTrue(request.requiresNetworkConnectivity)
    XCTAssertEqual(
      request.earliestBeginDate,
      now.addingTimeInterval(processingTaskRetryInterval)
    )
  }
}

private final class LockedCounter: @unchecked Sendable {
  private let lock = NSLock()
  private var count = 0

  func increment() {
    lock.lock()
    count += 1
    lock.unlock()
  }

  var value: Int {
    lock.lock()
    defer { lock.unlock() }
    return count
  }
}
