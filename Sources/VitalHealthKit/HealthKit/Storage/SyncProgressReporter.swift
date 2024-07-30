@_spi(VitalSDKInternals) import VitalCore
import Foundation
import UIKit

final class SyncProgressReporter: @unchecked Sendable {
  
  private var active: Int = 0
  private let lock = NSLock()

  static let shared = SyncProgressReporter()
  private static let scheduleKey = "SyncReportSchedule"

  init() {}

  func syncBegin() {
    lock.withLock { active += 1 }
  }

  func syncEnded() async {
    let updatedCount = lock.withLock {
      active -= 1
      return active
    }

    if updatedCount == 0 {
      await reportIfNeeded()
    }
  }

  private func reportIfNeeded() async {
    let storage = VitalBackStorage.live
    let schedule = storage.readDate(Self.scheduleKey) ?? .distantPast

    guard Date().timeIntervalSince(schedule) >= 0 else {
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
    let reportingInterval = healthKitStorage.getLocalSyncState()?.reportingInterval ?? (4 * 3600)
    let newSchedule = Date().addingTimeInterval(reportingInterval)
    storage.storeDate(newSchedule, Self.scheduleKey)
    VitalLogger.healthKit.info("done; next at \(newSchedule)", source: "SyncProgressReporter")
  }

  @MainActor
  private func captureDeviceInfo() -> SyncProgressReport.DeviceInfo {
    SyncProgressReport.DeviceInfo(
      osVersion: UIDevice.current.systemVersion,
      model: UIDevice.current.model,
      bundle: Bundle.main.bundleIdentifier ?? "",
      version: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "",
      build: Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""
    )
  }
}

private struct SyncProgressReport: Encodable {
  let syncProgress: SyncProgress
  let deviceInfo: DeviceInfo

  struct DeviceInfo: Encodable {
    let osVersion: String
    let model: String
    let bundle: String
    let version: String
    let build: String
  }
}
