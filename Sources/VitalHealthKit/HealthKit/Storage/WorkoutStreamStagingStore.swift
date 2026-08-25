import CryptoKit
import Foundation
import HealthKit
@_spi(VitalSDKInternals) import VitalCore

actor WorkoutStreamStagingStore {
  static let shared = WorkoutStreamStagingStore()

  private static let currentVersion = 1
  private static let ttl: TimeInterval = 7 * 24 * 60 * 60

  private let rootDirectoryURL: URL
  private let fileManager: FileManager

  init(
    rootDirectoryURL: URL? = nil,
    fileManager: FileManager = .default
  ) {
    if let rootDirectoryURL {
      self.rootDirectoryURL = rootDirectoryURL
    } else {
      let applicationSupport: URL
      if #available(iOS 16.0, *) {
        applicationSupport = URL.applicationSupportDirectory
      } else {
        applicationSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
      }

      self.rootDirectoryURL = applicationSupport
        .appendingPathComponent("io.tryvital.VitalHealthKit", isDirectory: true)
        .appendingPathComponent("WorkoutStreamStaging", isDirectory: true)
    }

    self.fileManager = fileManager
  }

  func reconcile(anchorStorage: AnchorStorage) {
    guard let sessions = try? fileManager.contentsOfDirectory(
      at: rootDirectoryURL,
      includingPropertiesForKeys: [.contentModificationDateKey],
      options: [.skipsHiddenFiles]
    ) else {
      return
    }

    for sessionURL in sessions {
      reconcileSession(at: sessionURL, anchorStorage: anchorStorage)
    }
  }

  func prepareSession(
    workouts: [HKWorkout],
    anchor: StoredAnchor?,
    baseAnchor: StoredAnchor?
  ) throws -> WorkoutStreamStagingSession {
    let id = try sessionID(
      workouts: workouts,
      anchor: anchor,
      baseAnchor: baseAnchor
    )

    let sessionURL = rootDirectoryURL.appendingPathComponent(id, isDirectory: true)
    let pagesURL = sessionURL.appendingPathComponent("pages", isDirectory: true)

    if fileManager.fileExists(atPath: manifestURL(for: id).path) {
      _ = try loadManifest(id)
      try fileManager.createDirectory(at: pagesURL, withIntermediateDirectories: true)
      try pruneUnreferencedPages(id: id)
      return WorkoutStreamStagingSession(id: id)
    }

    try fileManager.createDirectory(at: pagesURL, withIntermediateDirectories: true)

    let manifest = WorkoutStreamStagingManifest(
      version: Self.currentVersion,
      sessionID: id,
      createdAt: Date(),
      updatedAt: Date(),
      anchorKey: anchor?.key,
      baseAnchorFingerprint: try anchorFingerprint(baseAnchor?.anchor),
      resultingAnchorFingerprint: try anchorFingerprint(anchor?.anchor),
      hasMore: anchor?.hasMore ?? false,
      states: [:],
      pages: [],
      uploadState: .extracting,
      workItemIDs: nil,
      componentPlanFingerprint: nil,
      byteCount: nil
    )

    try writeManifest(manifest)
    return WorkoutStreamStagingSession(id: id)
  }

  func prepareWorklistSession(
    queue: [WorkoutStreamWorkItem],
    componentPlanFingerprint: String
  ) throws -> WorkoutStreamStagingSession {
    let queueIDs = queue.map(\.id)

    if let existing = try findReusableWorklistSession(
      queueIDs: queueIDs,
      componentPlanFingerprint: componentPlanFingerprint
    ) {
      try pruneUnreferencedPages(id: existing.id)
      return existing
    }

    try deleteWorklistSessions()

    let id = "worklist-" + UUID().uuidString.lowercased()
    let sessionURL = rootDirectoryURL.appendingPathComponent(id, isDirectory: true)
    let pagesURL = sessionURL.appendingPathComponent("pages", isDirectory: true)
    try fileManager.createDirectory(at: pagesURL, withIntermediateDirectories: true)

    let manifest = WorkoutStreamStagingManifest(
      version: Self.currentVersion,
      sessionID: id,
      createdAt: Date(),
      updatedAt: Date(),
      anchorKey: nil,
      baseAnchorFingerprint: nil,
      resultingAnchorFingerprint: nil,
      hasMore: false,
      states: [:],
      pages: [],
      uploadState: .extracting,
      workItemIDs: [],
      componentPlanFingerprint: componentPlanFingerprint,
      byteCount: 0
    )

    try writeManifest(manifest)
    return WorkoutStreamStagingSession(id: id)
  }

  func appendWorkItem(session: WorkoutStreamStagingSession, workoutID: UUID) throws {
    var manifest = try loadManifest(session.id)
    var workItemIDs = manifest.workItemIDs ?? []
    if workItemIDs.contains(workoutID) == false {
      workItemIDs.append(workoutID)
      manifest.workItemIDs = workItemIDs
      manifest.updatedAt = Date()
      try writeManifest(manifest)
    }
  }

  func workItemIDs(session: WorkoutStreamStagingSession) throws -> [UUID] {
    let manifest = try loadManifest(session.id)
    return manifest.workItemIDs ?? []
  }

  func byteCount(session: WorkoutStreamStagingSession) throws -> Int {
    let manifest = try loadManifest(session.id)
    if let byteCount = manifest.byteCount {
      return byteCount
    }
    return manifest.pages.reduce(0) { count, page in count + (page.byteCount ?? 0) }
  }

  func deleteSession(_ session: WorkoutStreamStagingSession) {
    let url = rootDirectoryURL.appendingPathComponent(session.id, isDirectory: true)
    try? fileManager.removeItem(at: url)
  }

  func state(
    session: WorkoutStreamStagingSession,
    workoutID: UUID,
    component: ManualWorkoutStream.Component,
    initialCursor: Date,
    windowEnd: Date
  ) throws -> WorkoutStreamTypeState {
    var manifest = try loadManifest(session.id)
    let key = typeStateKey(workoutID: workoutID, component: component)

    if let state = manifest.states[key] {
      return state
    }

    let state = WorkoutStreamTypeState(
      workoutID: workoutID,
      component: component,
      cursorStart: initialCursor.timeIntervalSinceReferenceDate,
      windowEnd: windowEnd.timeIntervalSinceReferenceDate,
      boundaryUUIDsAtCursor: [],
      exhausted: false,
      nextPageIndex: 0
    )

    manifest.states[key] = state
    manifest.updatedAt = Date()
    try writeManifest(manifest)
    return state
  }

  func appendPage(
    session: WorkoutStreamStagingSession,
    workoutID: UUID,
    component: ManualWorkoutStream.Component,
    quantityTypeIdentifier: String,
    cursorIn: Date,
    cursorOut: Date,
    boundaryUUIDsAtCursorOut: [UUID],
    samples: [BulkQuantitySample],
    exhausted: Bool
  ) throws -> WorkoutStreamTypeState {
    var manifest = try loadManifest(session.id)
    let key = typeStateKey(workoutID: workoutID, component: component)
    guard var state = manifest.states[key] else {
      throw VitalHealthKitClientError.sdkInvalidState("missing workout stream staging state")
    }

    let pageIndex = state.nextPageIndex
    let fileName = "\(workoutID.uuidString)-\(component.rawValue)-\(String(format: "%06d", pageIndex)).json"
    let pageURL = pagesURL(for: session.id).appendingPathComponent(fileName, isDirectory: false)
    let data = try JSONEncoder.vitalHealthKit.encode(samples)

    try fileManager.createDirectory(at: pagesURL(for: session.id), withIntermediateDirectories: true)
    try data.write(to: pageURL, options: [.atomic])

    let pageRef = WorkoutStreamPageRef(
      fileName: fileName,
      workoutID: workoutID,
      component: component,
      quantityTypeIdentifier: quantityTypeIdentifier,
      pageIndex: pageIndex,
      cursorIn: cursorIn.timeIntervalSinceReferenceDate,
      cursorOut: cursorOut.timeIntervalSinceReferenceDate,
      boundaryUUIDsAtCursorOut: boundaryUUIDsAtCursorOut,
      sha256: data.hexEncodedSHA256,
      byteCount: data.count,
      sampleCount: samples.reduce(0) { count, sample in count + sample.value.count }
    )

    state.cursorStart = cursorOut.timeIntervalSinceReferenceDate
    state.boundaryUUIDsAtCursor = boundaryUUIDsAtCursorOut
    state.exhausted = exhausted
    state.nextPageIndex = pageIndex + 1

    manifest.pages.append(pageRef)
    manifest.states[key] = state
    manifest.byteCount = (manifest.byteCount ?? 0) + data.count
    manifest.updatedAt = Date()
    if manifest.states.values.allSatisfy(\.exhausted) {
      manifest.uploadState = .readyToFlush
    }

    try writeManifest(manifest)
    return state
  }

  func markExhausted(
    session: WorkoutStreamStagingSession,
    workoutID: UUID,
    component: ManualWorkoutStream.Component
  ) throws -> WorkoutStreamTypeState {
    var manifest = try loadManifest(session.id)
    let key = typeStateKey(workoutID: workoutID, component: component)
    guard var state = manifest.states[key] else {
      throw VitalHealthKitClientError.sdkInvalidState("missing workout stream staging state")
    }

    state.exhausted = true
    manifest.states[key] = state
    manifest.updatedAt = Date()
    if manifest.states.values.allSatisfy(\.exhausted) {
      manifest.uploadState = .readyToFlush
    }

    try writeManifest(manifest)
    return state
  }

  func stream(
    session: WorkoutStreamStagingSession,
    workoutID: UUID,
    allowedComponents: Set<ManualWorkoutStream.Component>
  ) throws -> ManualWorkoutStream {
    let manifest = try loadManifest(session.id)
    var components: [ManualWorkoutStream.Component: [BulkQuantitySample]] = [:]

    for page in manifest.pages
      .filter({ $0.workoutID == workoutID && allowedComponents.contains($0.component) })
      .sorted(by: pageOrder)
    {
      let samples = try loadPage(sessionID: session.id, page: page)
      components[page.component, default: []].append(contentsOf: samples)
    }

    return ManualWorkoutStream(components: components)
  }

  func markUploaded(session: WorkoutStreamStagingSession) throws {
    var manifest = try loadManifest(session.id)
    manifest.uploadState = .uploaded
    manifest.updatedAt = Date()
    try writeManifest(manifest)
  }

  func deleteArtifactDirectory(_ artifact: StoredAnchorArtifactDirectory) {
    let url = rootDirectoryURL.appendingPathComponent(artifact.id, isDirectory: true)
    try? fileManager.removeItem(at: url)
  }

  func writeDiagnosticSnapshot(to destinationURL: URL) throws {
    try fileManager.createDirectory(
      at: destinationURL.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )

    guard fileManager.fileExists(atPath: rootDirectoryURL.path) else {
      try fileManager.createDirectory(at: destinationURL, withIntermediateDirectories: true)
      return
    }

    try fileManager.copyItem(at: rootDirectoryURL, to: destinationURL)
  }

  private func reconcileSession(at sessionURL: URL, anchorStorage: AnchorStorage) {
    let manifestURL = sessionURL.appendingPathComponent("manifest.json", isDirectory: false)

    guard fileManager.fileExists(atPath: manifestURL.path) else {
      try? fileManager.removeItem(at: sessionURL)
      return
    }

    guard let manifest = try? loadManifest(sessionURL.lastPathComponent) else {
      try? fileManager.removeItem(at: sessionURL)
      return
    }

    guard manifest.uploadState != .uploaded else {
      try? fileManager.removeItem(at: sessionURL)
      return
    }

    guard manifest.pages.allSatisfy({ pageExistsAndMatchesHash(sessionID: manifest.sessionID, page: $0) }) else {
      try? fileManager.removeItem(at: sessionURL)
      return
    }

    if let anchorKey = manifest.anchorKey,
       let currentFingerprint = try? anchorFingerprint(anchorStorage.read(key: anchorKey)?.anchor)
    {
      if currentFingerprint == manifest.resultingAnchorFingerprint {
        try? fileManager.removeItem(at: sessionURL)
        return
      }

      if
        let baseAnchorFingerprint = manifest.baseAnchorFingerprint,
        currentFingerprint != baseAnchorFingerprint
      {
        try? fileManager.removeItem(at: sessionURL)
        return
      }
    }

    if Date().timeIntervalSince(manifest.createdAt) > Self.ttl {
      VitalLogger.healthKit.info("deleting stale workout stream staging session \(manifest.sessionID)", source: "WorkoutStreamStaging")
      try? fileManager.removeItem(at: sessionURL)
      return
    }

    try? pruneUnreferencedPages(id: manifest.sessionID)
  }

  private func loadPage(sessionID: String, page: WorkoutStreamPageRef) throws -> [BulkQuantitySample] {
    let url = pagesURL(for: sessionID).appendingPathComponent(page.fileName, isDirectory: false)
    let data = try Data(contentsOf: url)

    guard data.hexEncodedSHA256 == page.sha256 else {
      throw VitalHealthKitClientError.sdkInvalidState("workout stream staging page hash mismatch")
    }

    return try JSONDecoder.vitalHealthKit.decode([BulkQuantitySample].self, from: data)
  }

  private func pageExistsAndMatchesHash(sessionID: String, page: WorkoutStreamPageRef) -> Bool {
    let url = pagesURL(for: sessionID).appendingPathComponent(page.fileName, isDirectory: false)
    guard let data = try? Data(contentsOf: url) else {
      return false
    }
    return data.hexEncodedSHA256 == page.sha256
  }

  private func pruneUnreferencedPages(id: String) throws {
    let manifest = try loadManifest(id)
    let referenced = Set(manifest.pages.map(\.fileName))
    let pagesURL = pagesURL(for: id)
    guard let files = try? fileManager.contentsOfDirectory(at: pagesURL, includingPropertiesForKeys: nil) else {
      return
    }

    for file in files where referenced.contains(file.lastPathComponent) == false {
      try? fileManager.removeItem(at: file)
    }
  }

  private func findReusableWorklistSession(
    queueIDs: [UUID],
    componentPlanFingerprint: String
  ) throws -> WorkoutStreamStagingSession? {
    guard let sessions = try? fileManager.contentsOfDirectory(
      at: rootDirectoryURL,
      includingPropertiesForKeys: [.contentModificationDateKey],
      options: [.skipsHiddenFiles]
    ) else {
      return nil
    }

    let reusable = sessions.compactMap { sessionURL -> WorkoutStreamStagingManifest? in
      guard let manifest = try? loadManifest(sessionURL.lastPathComponent),
            manifest.workItemIDs != nil
      else {
        return nil
      }

      guard manifest.uploadState != .uploaded,
            manifest.componentPlanFingerprint == componentPlanFingerprint,
            isPrefix(manifest.workItemIDs ?? [], of: queueIDs),
            manifest.pages.allSatisfy({ pageExistsAndMatchesHash(sessionID: manifest.sessionID, page: $0) })
      else {
        try? fileManager.removeItem(at: sessionURL)
        return nil
      }

      return manifest
    }

    return reusable
      .sorted { $0.updatedAt > $1.updatedAt }
      .first
      .map { WorkoutStreamStagingSession(id: $0.sessionID) }
  }

  private func deleteWorklistSessions() throws {
    guard let sessions = try? fileManager.contentsOfDirectory(
      at: rootDirectoryURL,
      includingPropertiesForKeys: nil,
      options: [.skipsHiddenFiles]
    ) else {
      return
    }

    for sessionURL in sessions {
      guard let manifest = try? loadManifest(sessionURL.lastPathComponent),
            manifest.workItemIDs != nil
      else {
        continue
      }

      try? fileManager.removeItem(at: sessionURL)
    }
  }

  private func isPrefix(_ prefix: [UUID], of values: [UUID]) -> Bool {
    guard prefix.count <= values.count else {
      return false
    }

    return zip(prefix, values).allSatisfy { $0 == $1 }
  }

  private func sessionID(
    workouts: [HKWorkout],
    anchor: StoredAnchor?,
    baseAnchor: StoredAnchor?
  ) throws -> String {
    let workoutParts = workouts
      .map { workout in
        [
          workout.uuid.uuidString,
          String(workout.startDate.timeIntervalSinceReferenceDate),
          String(workout.endDate.timeIntervalSinceReferenceDate),
          workout.workoutActivityType.toString,
        ].joined(separator: ":")
      }
      .sorted()
      .joined(separator: "|")

    let input = [
      "apple_health_kit",
      "workouts",
      anchor?.key ?? "no-anchor-key",
      try anchorFingerprint(baseAnchor?.anchor) ?? "no-base-anchor",
      try anchorFingerprint(anchor?.anchor) ?? "no-result-anchor",
      workoutParts,
    ].joined(separator: "\n")

    return "session-" + input.hexEncodedSHA256.prefix(32)
  }

  private func anchorFingerprint(_ anchor: HKQueryAnchor?) throws -> String? {
    guard let anchor else {
      return nil
    }

    let data = try NSKeyedArchiver.archivedData(withRootObject: anchor, requiringSecureCoding: true)
    return data.hexEncodedSHA256
  }

  private func typeStateKey(workoutID: UUID, component: ManualWorkoutStream.Component) -> String {
    "\(workoutID.uuidString)/\(component.rawValue)"
  }

  private func manifestURL(for id: String) -> URL {
    rootDirectoryURL
      .appendingPathComponent(id, isDirectory: true)
      .appendingPathComponent("manifest.json", isDirectory: false)
  }

  private func pagesURL(for id: String) -> URL {
    rootDirectoryURL
      .appendingPathComponent(id, isDirectory: true)
      .appendingPathComponent("pages", isDirectory: true)
  }

  private func loadManifest(_ id: String) throws -> WorkoutStreamStagingManifest {
    let data = try Data(contentsOf: manifestURL(for: id))
    return try JSONDecoder.vitalHealthKit.decode(WorkoutStreamStagingManifest.self, from: data)
  }

  private func writeManifest(_ manifest: WorkoutStreamStagingManifest) throws {
    let url = manifestURL(for: manifest.sessionID)
    try fileManager.createDirectory(
      at: url.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    let data = try JSONEncoder.vitalHealthKit.encode(manifest)
    try data.write(to: url, options: [.atomic])
  }

  private func pageOrder(_ lhs: WorkoutStreamPageRef, _ rhs: WorkoutStreamPageRef) -> Bool {
    if lhs.workoutID != rhs.workoutID {
      return lhs.workoutID.uuidString < rhs.workoutID.uuidString
    }
    if lhs.component != rhs.component {
      return lhs.component.rawValue < rhs.component.rawValue
    }
    return lhs.pageIndex < rhs.pageIndex
  }
}

struct WorkoutStreamStagingSession: Sendable {
  let id: String

  var artifactDirectory: StoredAnchorArtifactDirectory {
    StoredAnchorArtifactDirectory(id: id)
  }
}

private struct WorkoutStreamStagingManifest: Codable {
  var version: Int
  var sessionID: String
  var createdAt: Date
  var updatedAt: Date
  var anchorKey: String?
  var baseAnchorFingerprint: String?
  var resultingAnchorFingerprint: String?
  var hasMore: Bool
  var states: [String: WorkoutStreamTypeState]
  var pages: [WorkoutStreamPageRef]
  var uploadState: WorkoutStreamUploadState
  var workItemIDs: [UUID]?
  var componentPlanFingerprint: String?
  var byteCount: Int?
}

struct WorkoutStreamTypeState: Codable, Sendable {
  var workoutID: UUID
  var component: ManualWorkoutStream.Component
  var cursorStart: TimeInterval
  var windowEnd: TimeInterval
  var boundaryUUIDsAtCursor: [UUID]
  var exhausted: Bool
  var nextPageIndex: Int
}

private struct WorkoutStreamPageRef: Codable {
  var fileName: String
  var workoutID: UUID
  var component: ManualWorkoutStream.Component
  var quantityTypeIdentifier: String
  var pageIndex: Int
  var cursorIn: TimeInterval
  var cursorOut: TimeInterval?
  var boundaryUUIDsAtCursorOut: [UUID]
  var sha256: String
  var byteCount: Int?
  var sampleCount: Int
}

private enum WorkoutStreamUploadState: String, Codable {
  case extracting
  case readyToFlush
  case uploaded
}

private extension JSONEncoder {
  static var vitalHealthKit: JSONEncoder {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    encoder.outputFormatting = [.sortedKeys]
    return encoder
  }
}

private extension JSONDecoder {
  static var vitalHealthKit: JSONDecoder {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return decoder
  }
}

private extension Data {
  var hexEncodedSHA256: String {
    SHA256.hash(data: self).map { String(format: "%02x", $0) }.joined()
  }
}

private extension String {
  var hexEncodedSHA256: String {
    Data(self.utf8).hexEncodedSHA256
  }
}
