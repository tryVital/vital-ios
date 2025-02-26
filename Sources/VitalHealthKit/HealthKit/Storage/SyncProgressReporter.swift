@_spi(VitalSDKInternals) import VitalCore
import Foundation
import UIKit

final class SyncProgressReporter: @unchecked Sendable {
  
  private var active: Set<SyncProgress.SyncID> = []
  private let lock = NSLock()

  static let shared = SyncProgressReporter()
  private static let scheduleKey = "SyncReportSchedule"
  private let parkingLot = ParkingLot().semaphore

  init() {}

  func syncBegin(_ id: SyncProgress.SyncID) {
    lock.withLock { _ = active.insert(id) }
  }

  func syncEnded(_ id: SyncProgress.SyncID) async {
    let updatedCount = lock.withLock {
      _ = active.remove(id)
      return active.count
    }

    if updatedCount == 0 {
      try? await reportIfNeeded(force: false)
    }
  }

  func syncingResources() -> Set<VitalResource> {
    return Set(lock.withLock { active }.map { $0.resource })
  }

  func report() async throws {
    try await reportIfNeeded(force: true)
  }

  func nextSchedule() -> Date? {
    let storage = VitalBackStorage.live
    return storage.readDate(Self.scheduleKey)
  }

  private func reportIfNeeded(force: Bool) async throws {
    try await parkingLot.acquire()
    defer { parkingLot.release() }

    let storage = VitalBackStorage.live
    let schedule = storage.readDate(Self.scheduleKey) ?? .distantPast

    guard force || Date().timeIntervalSince(schedule) >= 0 else {
      VitalLogger.healthKit.info("skipped; next at \(schedule)", source: "SyncProgressReporter")
      return
    }

    let progress = SyncProgressStore.shared.get()
    do {
      let deviceInfo = await captureDeviceInfo()
      let report = SyncProgressReport(syncProgress: progress, deviceInfo: deviceInfo)
      try await VitalClient.shared.user.sdkReportSyncProgress(body: report)
    } catch let error {
      VitalLogger.healthKit.error("failed to report sync progress: \(error)", source: "SyncProgressReporter")
    }

    // Every 4 hours
    let healthKitStorage = VitalHealthKitStorage(storage: storage)
    let reportingInterval = healthKitStorage.getLocalSyncState()?.reportingInterval ?? 3600
    let newSchedule = Date().addingTimeInterval(reportingInterval)
    storage.storeDate(newSchedule, Self.scheduleKey)
    VitalLogger.healthKit.info("done; next at \(newSchedule)", source: "SyncProgressReporter")
  }

  @MainActor
  private func captureDeviceInfo() -> SyncProgressReport.DeviceInfo {
    SyncProgressReport.DeviceInfo(
      osVersion: UIDevice.current.systemVersion,
      model: UIDevice.current.model,
      appBundle: Bundle.main.bundleIdentifier ?? "",
      appVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "",
      appBuild: Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""
    )
  }
}

private struct SyncProgressReport: Encodable {
  let syncProgress: SyncProgress
  let deviceInfo: DeviceInfo

  struct DeviceInfo: Encodable {
    let osVersion: String
    let model: String
    let appBundle: String
    let appVersion: String
    let appBuild: String
  }
}
