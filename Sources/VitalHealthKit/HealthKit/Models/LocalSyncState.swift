import Foundation
import VitalCore
@_spi(VitalSDKInternals) import VitalCore
import HealthKit

extension UserSDKHealthKitParams {
  static let `default` = UserSDKHealthKitParams(
    queryChunkSizesBackground: UserSDKHealthKitQueryChunkSizes(
      timeseries: 2500,
      electrocardiogram: 1,
      workout: 1,
      // IMPORTANT: The current Sleep Session stitching algorithm is not chunkable.
      // So this must be 0.
      sleep: 0,
      activityTimeseries: 2500
    ),

    queryChunkSizesForeground: UserSDKHealthKitQueryChunkSizes(
      timeseries: 10000,
      electrocardiogram: 4,
      workout: 5,
      // IMPORTANT: The current Sleep Session stitching algorithm is not chunkable.
      // So this must be 0.
      sleep: 0,
      activityTimeseries: 10000
    )
  )
}

internal struct LocalSyncState: Codable {
  let status: Status?
  
  let historicalStageAnchor: Date
  let defaultDaysToBackfill: Int
  let teamDataPullPreferences: TeamDataPullPreferences?

  let ingestionStart: Date
  let ingestionEnd: Date?
  let perDeviceActivityTS: Bool

  let expiresAt: Date
  let reportingInterval: Double?

  var params: UserSDKHealthKitParams

  init(status: Status?, historicalStageAnchor: Date, defaultDaysToBackfill: Int, teamDataPullPreferences: TeamDataPullPreferences?, ingestionStart: Date, ingestionEnd: Date?, perDeviceActivityTS: Bool, expiresAt: Date, reportingInterval: Double?, params: UserSDKHealthKitParams) {
    self.status = status
    self.historicalStageAnchor = historicalStageAnchor
    self.defaultDaysToBackfill = defaultDaysToBackfill
    self.teamDataPullPreferences = teamDataPullPreferences
    self.ingestionStart = ingestionStart
    self.ingestionEnd = ingestionEnd
    self.perDeviceActivityTS = perDeviceActivityTS
    self.expiresAt = expiresAt
    self.reportingInterval = reportingInterval
    self.params = params
  }

  init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.status = try container.decodeIfPresent(Status.self, forKey: .status)
    self.historicalStageAnchor = try container.decode(Date.self, forKey: .historicalStageAnchor)
    self.defaultDaysToBackfill = try container.decode(Int.self, forKey: .defaultDaysToBackfill)
    self.teamDataPullPreferences = try container.decodeIfPresent(TeamDataPullPreferences.self, forKey: .teamDataPullPreferences)
    self.ingestionStart = try container.decode(Date.self, forKey: .ingestionStart)
    self.ingestionEnd = try container.decodeIfPresent(Date.self, forKey: .ingestionEnd)
    self.perDeviceActivityTS = try container.decode(Bool.self, forKey: .perDeviceActivityTS)
    self.expiresAt = try container.decode(Date.self, forKey: .expiresAt)
    self.reportingInterval = try container.decodeIfPresent(Double.self, forKey: .reportingInterval)
    self.params = try container.decodeIfPresent(UserSDKHealthKitParams.self, forKey: .params) ?? UserSDKHealthKitParams.default
  }

  func historicalStartDate(for resource: VitalResource) -> Date {
    let backfillType = resource.backfillType
    let daysToBackfill = teamDataPullPreferences?.backfillTypeOverrides?[backfillType]?.historicalDaysToPull ?? teamDataPullPreferences?.historicalDaysToPull;

    let calculatedDate = Date.dateAgo(historicalStageAnchor, days: daysToBackfill ?? defaultDaysToBackfill)
    return max(ingestionStart, calculatedDate)
  }
}


struct SyncInstruction: CustomStringConvertible {
  let stage: Stage
  let query: Range<Date>

  public var description: String {
    return "\(stage): \(query.lowerBound) - \(query.upperBound)"
  }

  var taggedPayloadStage: TaggedPayload.Stage {
    switch stage {
    case .daily:
      return .daily
    case .historical:
      return .historical(start: query.lowerBound, end: query.upperBound)
    }
  }
}
