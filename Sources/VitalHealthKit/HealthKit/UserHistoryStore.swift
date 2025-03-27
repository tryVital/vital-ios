@_spi(VitalSDKInternals) import VitalCore
import Foundation
import HealthKit

class UserHistoryStore: @unchecked Sendable {
  static let shared = UserHistoryStore()

  internal static var getCurrentTimeZone = { TimeZone.current }
  static let keepMostRecent = 30

  private var hasLoaded = false
  private var data: [GregorianCalendar.FloatingDate: UserHistoryRecord] = [:]
  private let lock = NSLock()

  private let storage: VitalGistStorage

  init(storage: VitalGistStorage = .shared) {
    self.storage = storage
  }

  private func loadIfNeeded() {
    if !hasLoaded {
      hasLoaded = true
      self.data = self.storage.get(UserTimeZoneHistory.self) ?? [:]
      VitalLogger.healthKit.info("loaded \(self.data.count) records", source: "UserHistoryStore")
    }
  }

  private func save() {
    // Trim oldest entries if we go above `keepMostRecent` days.
    let keysToDrop = self.data.keys.sorted(by: >).dropFirst(Self.keepMostRecent)

    for key in keysToDrop {
      self.data.removeValue(forKey: key)
    }

    try? self.storage.set(self.data, for: UserTimeZoneHistory.self)
  }

  func record(_ timeZone: TimeZone, date: GregorianCalendar.Date? = nil) {
    let dateToUpdate = date ?? GregorianCalendar(timeZone: timeZone).floatingDate(of: Date())
    let zoneId = timeZone.identifier
    let wheelchairUse = try? HKHealthStore().wheelchairUse()

    return lock.withLock {
      loadIfNeeded()

      let oldValue = self.data[dateToUpdate]
      let newValue = UserHistoryRecord(timeZoneId: zoneId, wheelchairUse: wheelchairUse?.wheelchairUse == .yes)
      self.data[dateToUpdate] = newValue

      if oldValue != newValue {
        save()

        VitalLogger.healthKit.info(
          "\(dateToUpdate) old: \(oldValue.map(String.init(describing:)) ?? "nil") new: \(newValue)",
          source: "UserHistoryStore"
        )
      }
    }
  }

  func resolver() -> Resolver {
    let current = lock.withLock {
      loadIfNeeded()
      return self.data
    }

    return Resolver(data: current)
  }

  struct Resolver {
    let data: [GregorianCalendar.FloatingDate: UserHistoryRecord]

    func timeZone(for date: GregorianCalendar.FloatingDate) -> TimeZone {

      if let zoneId = data[date]?.timeZoneId, let timeZone = TimeZone(identifier: zoneId) {
        return timeZone
      }

      // Find the closest observation
      if
        let closestDate = data.keys.lazy.filter({ $0 < date }).max(),
        let nextZoneId = data[closestDate]?.timeZoneId,
        let timeZone = TimeZone(identifier: nextZoneId)
      {
        return timeZone
      }

      // No match, fallback to current time zone
      return UserHistoryStore.getCurrentTimeZone()
    }
  }
}

struct UserHistoryRecord: Codable, Equatable {
  let timeZoneId: String
  let wheelchairUse: Bool?
}

enum UserTimeZoneHistory: GistKey {
  typealias T = [GregorianCalendar.FloatingDate: UserHistoryRecord]
  static var identifier: String { "vital_user_timezone_history" }
}
