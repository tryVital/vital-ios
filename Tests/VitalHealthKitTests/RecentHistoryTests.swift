import XCTest
import HealthKit
@_spi(VitalSDKInternals) @testable import VitalHealthKit
@_spi(VitalSDKInternals) @testable import VitalCore

final class RecentHistoryTests: XCTestCase {
  func state(days: Int, pullId: UUID? = UUID(), ingestionEnd: Date? = nil) -> LocalSyncState {
    let end = ISO8601DateFormatter().date(from: "2026-11-27T12:00:00Z")!
    return LocalSyncState(status: .active, historicalStageAnchor: end, defaultDaysToBackfill: days,
      teamDataPullPreferences: nil, ingestionStart: .distantPast, ingestionEnd: ingestionEnd,
      perDeviceActivityTS: false, expiresAt: .distantFuture, reportingInterval: nil,
      params: .default, historicalPullId: pullId)
  }

  func testShortAndLegacyHistoryHaveNoExtraPass() {
    for days in [7, 30] {
      XCTAssertNil(RecentHistoryPass.make(state: state(days: days), resource: .vitals(.heartRate), permissions: []))
    }
    XCTAssertNil(RecentHistoryPass.make(state: state(days: 90, pullId: nil), resource: .vitals(.heartRate), permissions: []))
  }

  func testRecentWindowUsesThirtyCalendarDatesAndFreezesFullBounds() throws {
    let local = state(days: 90)
    let pass = try XCTUnwrap(RecentHistoryPass.make(state: local, resource: .vitals(.heartRate),
      permissions: ["heartRate"], timeZone: TimeZone(secondsFromGMT: 0)!))
    let metadata = try XCTUnwrap(pass.upload(isLastBatch: true).recentPass)
    XCTAssertEqual(metadata.startDate, "2026-10-29")
    XCTAssertEqual(metadata.endDate, "2026-11-27")
    XCTAssertEqual(pass.historyStart, local.historicalStartDate(for: .vitals(.heartRate)))
    XCTAssertEqual(pass.historyEnd, local.historicalStageAnchor)
  }

  func testRecentCheckpointsSurviveRestartWithoutChangingNormalAnchors() throws {
    let backing = VitalBackStorage.debug
    let storage = VitalHealthKitStorage(storage: backing)
    let resource = VitalHealthKitStore.remapResource(.vitals(.heartRate))
    let key = HKQuantityType.quantityType(forIdentifier: .heartRate)!.identifier
    var pass = try XCTUnwrap(RecentHistoryPass.make(state: state(days: 90), resource: resource.wrapped, permissions: []))
    let recent = storage.recentStorage(for: resource)
    recent.store(entity: StoredAnchor(key: key, anchor: HKQueryAnchor(fromValue: 4), date: nil, vitalAnchors: nil))
    pass.completed = true
    try storage.setRecentPass(pass, for: resource)
    let restarted = VitalHealthKitStorage(storage: backing)
    XCTAssertNil(restarted.read(key: key))
    XCTAssertFalse(restarted.historicalStageDone(for: resource))
    XCTAssertNotNil(restarted.recentStorage(for: resource).read(key: key)?.anchor)
    XCTAssertEqual(try restarted.recentPass(for: resource)?.completed, true)
    restarted.clearRecentAnchors(for: resource)
    XCTAssertNil(restarted.recentStorage(for: resource).read(key: key))
  }

  func testRecentUploadDoesNotClaimFullCompletion() throws {
    let pass = try XCTUnwrap(RecentHistoryPass.make(state: state(days: 90), resource: .vitals(.heartRate), permissions: []))
    let payload = TaggedPayload(stage: .historical(start: pass.historyStart, end: pass.historyEnd),
      timeZone: .current, data: VitalAnyEncodable([Int]()), isFinalChunk: false,
      historicalUpload: pass.upload(isLastBatch: true))
    let encoder = JSONEncoder()
    encoder.keyEncodingStrategy = .convertToSnakeCase
    let json = try XCTUnwrap(JSONSerialization.jsonObject(with: encoder.encode(payload)) as? [String: Any])
    XCTAssertEqual(json["is_final_chunk"] as? Bool, false)
    XCTAssertEqual((json["recent_pass"] as? [String: Any])?["is_last_batch"] as? Bool, true)
    let daily = TaggedPayload(timeZone: .current, data: VitalAnyEncodable([Int]()))
    let dailyJSON = try XCTUnwrap(JSONSerialization.jsonObject(with: encoder.encode(daily)) as? [String: Any])
    XCTAssertNil(dailyJSON["historical_pull_id"])
    XCTAssertNil(dailyJSON["recent_pass"])
  }

  func testEmptyAggregateRecentPassUploadsMarkerWithoutCompletingHistory() async throws {
    for resource: VitalResource in [.body, .activity] {
      let storage = VitalHealthKitStorage(storage: .debug)
      try storage.setLocalSyncState(state(days: 90))
      var store = VitalHealthKitStore.debug
      store.authorizationState = { _ in ([resource: true], [:], []) }
      store.readResource = { _, _, _, _ in (nil, []) }
      var backend = VitalClientProtocol.debug
      var uploads: [(ProcessedResourceData, Bool, SDKHistoricalUpload?)] = []
      backend.post = { data, _, _, _, final, metadata in uploads.append((data, final, metadata)) }
      backend.sdkStartHistoricalStage = { _ in }
      let client = VitalHealthKitClient(configuration: .init(value: .init()), store: store, storage: storage, vitalClient: backend)
      try await client.syncRecentHistory([])
      XCTAssertEqual(uploads.count, 1)
      XCTAssertEqual(uploads.first?.0.dataCount, 0)
      XCTAssertEqual(uploads.first?.1, false)
      XCTAssertEqual(uploads.first?.2?.recentPass?.isLastBatch, true)
      let body = VitalHealthKitStore.remapResource(resource)
      XCTAssertEqual(try storage.recentPass(for: body)?.completed, true)
      XCTAssertFalse(storage.historicalStageDone(for: body))
    }
  }

  func testFailedRecentResourceBlocksFullHistoryUntilRetry() async throws {
    let storage = VitalHealthKitStorage(storage: .debug)
    try storage.setLocalSyncState(state(days: 90))
    var store = VitalHealthKitStore.debug
    store.authorizationState = { _ in ([.body: true, .vitals(.heartRate): true], [:], []) }
    var failHeartRate = true
    store.readResource = { resource, _, _, _ in
      if resource.wrapped == .vitals(.heartRate) && failHeartRate { throw URLError(.networkConnectionLost) }
      return resource.wrapped == .body ? (nil, []) : (.timeSeries(.heartRate([])), [])
    }
    var backend = VitalClientProtocol.debug
    backend.sdkStartHistoricalStage = { _ in }
    let client = VitalHealthKitClient(configuration: .init(value: .init()), store: store, storage: storage, vitalClient: backend)
    let first = try await client.syncRecentHistory([])
    XCTAssertFalse(first)
    XCTAssertEqual(try storage.recentPass(for: VitalHealthKitStore.remapResource(.body))?.completed, true)
    failHeartRate = false
    let retry = try await client.syncRecentHistory([])
    XCTAssertTrue(retry)
  }

  func testWorkoutSummaryAndEmptyStreamsEmitOneRecentMilestone() async throws {
    let storage = VitalHealthKitStorage(storage: .debug)
    try storage.setLocalSyncState(state(days: 90))
    var store = VitalHealthKitStore.debug
    store.authorizationState = { _ in ([.workout: true, .workoutStream: true], [:], []) }
    var failStream = true
    store.readResource = { resource, _, _, _ in
      if resource.wrapped == .workoutStream && failStream { throw URLError(.networkConnectionLost) }
      return resource.wrapped == .workout ? (.summary(.workout(WorkoutPatch(workouts: []))), []) : (nil, [])
    }
    var backend = VitalClientProtocol.debug
    var markers: [Bool] = []
    backend.post = { _, _, _, _, final, metadata in
      XCTAssertFalse(final)
      markers.append(metadata?.recentPass?.isLastBatch ?? false)
    }
    backend.sdkStartHistoricalStage = { _ in }
    let client = VitalHealthKitClient(configuration: .init(value: .init()), store: store, storage: storage, vitalClient: backend)
    let failed = try await client.syncRecentHistory([])
    XCTAssertFalse(failed)
    XCTAssertEqual(markers, [false])
    failStream = false
    let completed = try await client.syncRecentHistory([])
    XCTAssertTrue(completed)
    XCTAssertEqual(markers, [false, true])
  }

  func testShortenedHistoryDoesNotWaitForObsoleteRecentCheckpoint() async throws {
    let storage = VitalHealthKitStorage(storage: .debug)
    let original = state(days: 90)
    let resource = VitalHealthKitStore.remapResource(.body)
    let pass = try XCTUnwrap(RecentHistoryPass.make(state: original, resource: .body, permissions: []))
    try storage.setRecentPass(pass, for: resource)
    try storage.setLocalSyncState(state(days: 30, pullId: original.historicalPullId))
    var store = VitalHealthKitStore.debug
    store.authorizationState = { _ in ([.body: true], [:], []) }
    store.readResource = { _, _, _, _ in XCTFail("Ineligible recent pass must not read"); return (nil, []) }
    let client = VitalHealthKitClient(configuration: .init(value: .init()), store: store, storage: storage, vitalClient: .debug)
    let readyForFull = try await client.syncRecentHistory([])
    XCTAssertTrue(readyForFull)
  }

  func testCompletedRecentPassIsNotRepeatedWhenBoundsChange() async throws {
    let storage = VitalHealthKitStorage(storage: .debug)
    let original = state(days: 90)
    try storage.setLocalSyncState(original)
    var store = VitalHealthKitStore.debug
    store.authorizationState = { _ in ([.body: true], [:], []) }
    store.readResource = { _, _, _, _ in (nil, []) }
    var backend = VitalClientProtocol.debug
    var uploads = 0
    backend.post = { _, _, _, _, _, _ in uploads += 1 }
    backend.sdkStartHistoricalStage = { _ in }
    let client = VitalHealthKitClient(configuration: .init(value: .init()), store: store, storage: storage, vitalClient: backend)
    try await client.syncRecentHistory([])
    XCTAssertEqual(uploads, 1)
    try storage.setLocalSyncState(state(days: 90, pullId: original.historicalPullId,
      ingestionEnd: original.historicalStageAnchor.addingTimeInterval(-86400)))
    try await client.syncRecentHistory([])
    XCTAssertEqual(uploads, 1)
    XCTAssertFalse(storage.historicalStageDone(for: VitalHealthKitStore.remapResource(.body)))
  }

  func testRecentWorkoutStreamWaitsForSuccessfulWorkoutRetry() async throws {
    let storage = VitalHealthKitStorage(storage: .debug)
    try storage.setLocalSyncState(state(days: 90))
    var store = VitalHealthKitStore.debug
    store.authorizationState = { _ in ([.workout: true, .workoutStream: true], [:], []) }
    var failWorkout = true
    var streamReads = 0
    store.readResource = { resource, _, _, _ in
      if resource.wrapped == .workout && failWorkout { throw URLError(.networkConnectionLost) }
      if resource.wrapped == .workoutStream { streamReads += 1 }
      return (resource.wrapped == .workout ? .summary(.workout(WorkoutPatch(workouts: []))) : nil, [])
    }
    var backend = VitalClientProtocol.debug
    backend.sdkStartHistoricalStage = { _ in }
    let client = VitalHealthKitClient(configuration: .init(value: .init()), store: store, storage: storage, vitalClient: backend)
    try await client.syncRecentHistory([])
    let stream = VitalHealthKitStore.remapResource(.workoutStream)
    XCTAssertEqual(streamReads, 0)
    XCTAssertEqual(try storage.recentPass(for: stream)?.completed, false)
    failWorkout = false
    try await client.syncRecentHistory([])
    XCTAssertEqual(streamReads, 1)
    XCTAssertEqual(try storage.recentPass(for: stream)?.completed, true)
  }

  func testRecentAndFullHistoryShareTheOriginalEndAfterBoundsRefresh() throws {
    let anchor = state(days: 90).historicalStageAnchor
    for end in [anchor.addingTimeInterval(86400), anchor.addingTimeInterval(-86400)] {
      let local = state(days: 90, ingestionEnd: end)
      let recent = try XCTUnwrap(RecentHistoryPass.make(state: local, resource: .body, permissions: []))
      XCTAssertEqual(local.historicalEndDate, min(anchor, end))
      XCTAssertEqual(recent.historyEnd, local.historicalEndDate)
    }
  }

  func testBackendPausePreservesPullIdentityForResume() async throws {
    let storage = VitalHealthKitStorage(storage: .debug)
    let original = state(days: 90)
    try storage.setLocalSyncState(original)
    var paused = true
    var backend = VitalClientProtocol.debug
    backend.sdkStateSync = { request in
      XCTAssertTrue(request.supportsHistoricalProgress)
      let payload = paused ? "{\"status\":\"paused\"}" : "{\"status\":\"active\",\"historical_pull_id\":\"\(original.historicalPullId!)\"}"
      let decoder = JSONDecoder()
      decoder.keyDecodingStrategy = .convertFromSnakeCase
      return try decoder.decode(UserSDKSyncStateResponse.self, from: Data(payload.utf8))
    }
    let client = VitalHealthKitClient(configuration: .init(value: .init()), store: .debug, storage: storage, vitalClient: backend)
    do {
      _ = try await client.getLocalSyncState(forceRemoteCheck: true)
      XCTFail("Paused connection must not sync")
    } catch VitalHealthKitClientError.connectionPaused {}
    XCTAssertEqual(storage.getLocalSyncState()?.historicalPullId, original.historicalPullId)
    paused = false
    let resumed = try await client.getLocalSyncState(forceRemoteCheck: true)
    XCTAssertEqual(resumed.status, .active)
    XCTAssertEqual(resumed.historicalPullId, original.historicalPullId)
  }

}
