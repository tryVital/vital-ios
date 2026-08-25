@_spi(VitalSDKInternals) @testable import VitalCore
@testable import VitalHealthKit
import Foundation
import XCTest

final class WorkoutStreamArchiveTests: XCTestCase {
  private var testDirectory: URL!

  override func setUpWithError() throws {
    testDirectory = FileManager.default.temporaryDirectory
      .appendingPathComponent("workout-stream-archive-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: testDirectory, withIntermediateDirectories: true)
  }

  override func tearDownWithError() throws {
    try FileManager.default.removeItem(at: testDirectory)
  }

  func testWorklistDiagnosticSnapshotContainsPendingItems() async throws {
    let storageURL = testDirectory.appendingPathComponent("gist", isDirectory: true)
    let store = WorkoutStreamWorklistStore(storage: VitalGistStorage(directoryURL: storageURL))
    let workoutID = UUID()
    let workout = WorkoutPatch.Workout(
      id: workoutID,
      startDate: Date(timeIntervalSince1970: 1_700_000_000),
      endDate: Date(timeIntervalSince1970: 1_700_003_600),
      movingTime: 3_600,
      sourceBundle: "com.example.workouts",
      productType: "Watch",
      sport: "running",
      calories: 500,
      distance: 10_000
    )
    await store.enqueue([workout])

    let snapshotURL = testDirectory.appendingPathComponent("archive/worklist.json")
    try await store.writeDiagnosticSnapshot(to: snapshotURL)

    let object = try XCTUnwrap(
      JSONSerialization.jsonObject(with: Data(contentsOf: snapshotURL)) as? [String: Any]
    )
    let items = try XCTUnwrap(object["items"] as? [[String: Any]])
    XCTAssertEqual(items.count, 1)
    XCTAssertEqual(items.first?["id"] as? String, workoutID.uuidString)
  }

  func testStagingDiagnosticSnapshotCopiesArtifacts() async throws {
    let sourceURL = testDirectory.appendingPathComponent("source", isDirectory: true)
    let sessionURL = sourceURL.appendingPathComponent("worklist-session", isDirectory: true)
    let pagesURL = sessionURL.appendingPathComponent("pages", isDirectory: true)
    try FileManager.default.createDirectory(at: pagesURL, withIntermediateDirectories: true)
    try Data("manifest".utf8).write(
      to: sessionURL.appendingPathComponent("manifest.json", isDirectory: false)
    )
    try Data("page".utf8).write(
      to: pagesURL.appendingPathComponent("page.json", isDirectory: false)
    )

    let store = WorkoutStreamStagingStore(rootDirectoryURL: sourceURL)
    let snapshotURL = testDirectory.appendingPathComponent("archive/staging", isDirectory: true)
    try await store.writeDiagnosticSnapshot(to: snapshotURL)

    XCTAssertEqual(
      try Data(contentsOf: snapshotURL.appendingPathComponent("worklist-session/manifest.json")),
      Data("manifest".utf8)
    )
    XCTAssertEqual(
      try Data(contentsOf: snapshotURL.appendingPathComponent("worklist-session/pages/page.json")),
      Data("page".utf8)
    )
  }
}
