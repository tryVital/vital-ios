import Foundation
import VitalCore

struct RecentHistoryPass: Codable {
  let pullId: UUID
  let historyStart: Date
  let historyEnd: Date
  let recentStart: Date
  let timeZone: String
  let permissions: [String]
  var completed = false

  static func make(state: LocalSyncState, resource: VitalResource, permissions: [String], timeZone: TimeZone = .current) -> RecentHistoryPass? {
    guard let pullId = state.historicalPullId else { return nil }
    let start = state.historicalStartDate(for: resource)
    let end = state.historicalEndDate
    guard start < Date.dateAgo(end, days: 30) else { return nil }
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = timeZone
    let recentStart = calendar.date(byAdding: .day, value: -29, to: calendar.startOfDay(for: end))!
    return RecentHistoryPass(pullId: pullId, historyStart: start, historyEnd: end,
                             recentStart: max(start, recentStart), timeZone: timeZone.identifier, permissions: permissions)
  }

  func upload(isLastBatch: Bool) -> SDKHistoricalUpload {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.timeZone = TimeZone(identifier: timeZone)!
    formatter.dateFormat = "yyyy-MM-dd"
    return SDKHistoricalUpload(historicalPullId: pullId, recentPass: SDKRecentPass(
      startDate: formatter.string(from: recentStart), endDate: formatter.string(from: historyEnd), isLastBatch: isLastBatch))
  }
}
