import XCTest
import HealthKit

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

  func testBackgroundSyncDuration() {
    XCTAssertNil(
      backgroundSyncDuration(
        deadline: DispatchTime(uptimeNanoseconds: 120 * NSEC_PER_SEC),
        currentTime: DispatchTime(uptimeNanoseconds: 120 * NSEC_PER_SEC)
      )
    )
    XCTAssertEqual(
      backgroundSyncDuration(
        deadline: DispatchTime(uptimeNanoseconds: 120 * NSEC_PER_SEC),
        currentTime: DispatchTime(uptimeNanoseconds: 110 * NSEC_PER_SEC)
      ),
      10
    )
    XCTAssertEqual(
      backgroundSyncDeadline(
        from: DispatchTime(uptimeNanoseconds: 100 * NSEC_PER_SEC)
      ).uptimeNanoseconds,
      120 * NSEC_PER_SEC
    )
  }

  func testCancellationAwareContinuationReturnsResult() async throws {
    let value: Int = try await withCancellationAwareContinuation { continuation in
      continuation.resume(returning: 42)
    }

    XCTAssertEqual(value, 42)
  }

  func testCancellationAwareContinuationIgnoresLateResultAfterCancellation() async {
    let continuationBox = ProtectedBox<CancellationAwareContinuation<Int>>()
    let task = Task {
      try await withCancellationAwareContinuation { continuation in
        continuationBox.set(value: continuation)
      }
    }

    let continuation = await continuationBox.get()
    task.cancel()

    do {
      _ = try await task.value
      XCTFail("Expected cancellation")
    } catch is CancellationError {
      // Expected.
    } catch {
      XCTFail("Unexpected error: \(error)")
    }

    continuation.resume(returning: 42)
  }
}
