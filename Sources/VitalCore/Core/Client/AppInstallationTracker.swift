import Foundation

class AppInstallationTracker: @unchecked Sendable {
  static let shared = AppInstallationTracker()
  private static let keychainKey = "vital_installation_id"

  private let lock = NSLock()
  private var cachedID: UUID?

  init() {}

  func get() -> UUID {
    lock.withLock {
      if let value = cachedID {
        return value
      }

      // Try to backfill from Gist Storage
      if let record = VitalGistStorage.shared.get(AppInstallationTrackerGistKey.self) {
        self.cachedID = record.id
        return record.id
      }

      // Try to backfill from Keychain
      let storage = VitalSecureStorage(keychain: .makeLive(synchronizable: true))
      let finalID: UUID

      if let value = (try? storage.get(key: Self.keychainKey)).flatMap(UUID.init(uuidString:)) {
        finalID = value
      } else {
        finalID = UUID()
        setValue(finalID)
      }

      self.cachedID = finalID
      return finalID
    }
  }

  /// - precondition: Caller holds `self.lock`.
  private func setValue(_ newValue: UUID) {
    let storage = VitalSecureStorage(keychain: .makeLive(synchronizable: true))
    try? VitalGistStorage.shared.set(
      AppInstallation(id: newValue, createdAt: Date()),
      for: AppInstallationTrackerGistKey.self
    )
    try? storage.set(value: newValue.uuidString, key: Self.keychainKey)
  }
}

struct AppInstallation: Codable {
  let id: UUID
  let createdAt: Date
}

enum AppInstallationTrackerGistKey: GistKey {
  typealias T = AppInstallation
  static var identifier: String { "vital_installation_id" }
}
