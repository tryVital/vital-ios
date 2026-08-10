import Foundation

public struct CreateUserRequest: Encodable {
  public let clientUserId: String
  public let teamId: String?

  public init(clientUserId: String, teamId: String? = nil) {
    self.clientUserId = clientUserId
    self.teamId = teamId
  }
}

public struct CreateUserResponse: Decodable {
  public let clientUserId: String
  public let userId: UUID
}

public struct CreateSignInTokenResponse: Decodable {
  public let userId: UUID
  public let signInToken: String
}

public enum Status: String, Codable {
  case active
  case paused
  case error
}

public struct SingleBackfillTypeOverride: Codable {
  public let historicalDaysToPull: Int

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.historicalDaysToPull = try container.decode(Int.self, forKey: .historicalDaysToPull)
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(historicalDaysToPull, forKey: .historicalDaysToPull)
  }

  enum CodingKeys: String, CodingKey {
    case historicalDaysToPull
  }
}

@_spi(VitalSDKInternals)
public struct TeamDataPullPreferences: Codable {
  public let historicalDaysToPull: Int
  public let backfillTypeOverrides: [BackfillType: SingleBackfillTypeOverride]?

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.historicalDaysToPull = try container.decode(Int.self, forKey: .historicalDaysToPull)
    self.backfillTypeOverrides = try container.decodeIfPresent([String: SingleBackfillTypeOverride].self, forKey: .backfillTypeOverrides).map {
      Dictionary(uniqueKeysWithValues: $0.map { (BackfillType(rawValue: $0.key), $0.value) })
    } ?? nil
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(historicalDaysToPull, forKey: .historicalDaysToPull)

    if let backfillTypeOverrides = backfillTypeOverrides {
      let overrides = Dictionary(uniqueKeysWithValues: backfillTypeOverrides.map { ($0.key.rawValue, $0.value) })
      try container.encode(overrides, forKey: .backfillTypeOverrides)
    }
  }

  enum CodingKeys: String, CodingKey {
    case historicalDaysToPull
    case backfillTypeOverrides
  }
}

@_spi(VitalSDKInternals)
public struct UserSDKHealthKitQueryChunkSizes: Codable {
  public let timeseries: Int
  public let activityTimeseries: Int
  public let electrocardiogram: Int
  public let workout: Int
  public let sleep: Int

  public init(timeseries: Int, electrocardiogram: Int, workout: Int, sleep: Int, activityTimeseries: Int) {
    self.timeseries = timeseries
    self.electrocardiogram = electrocardiogram
    self.workout = workout
    self.sleep = sleep
    self.activityTimeseries = activityTimeseries
  }
}

@_spi(VitalSDKInternals)
public struct UserSDKHealthKitParams: Codable {
  public let queryChunkSizesBackground: UserSDKHealthKitQueryChunkSizes
  public let queryChunkSizesForeground: UserSDKHealthKitQueryChunkSizes
  public let workoutStream: Bool
  public let workoutHeartRate: Bool
  public let workoutStreamConcurrency: Int

  public init(queryChunkSizesBackground: UserSDKHealthKitQueryChunkSizes, queryChunkSizesForeground: UserSDKHealthKitQueryChunkSizes, workoutStream: Bool, workoutHeartRate: Bool, workoutStreamConcurrency: Int = 3) {
    self.queryChunkSizesBackground = queryChunkSizesBackground
    self.queryChunkSizesForeground = queryChunkSizesForeground
    self.workoutStream = workoutStream
    self.workoutHeartRate = workoutHeartRate
    self.workoutStreamConcurrency = workoutStreamConcurrency
  }

  private enum CodingKeys: String, CodingKey {
    case queryChunkSizesBackground
    case queryChunkSizesForeground
    case workoutStream
    case workoutHeartRate
    case workoutStreamConcurrency
  }

  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.queryChunkSizesBackground = try container.decode(UserSDKHealthKitQueryChunkSizes.self, forKey: .queryChunkSizesBackground)
    self.queryChunkSizesForeground = try container.decode(UserSDKHealthKitQueryChunkSizes.self, forKey: .queryChunkSizesForeground)
    self.workoutStream = try container.decode(Bool.self, forKey: .workoutStream)
    self.workoutHeartRate = try container.decode(Bool.self, forKey: .workoutHeartRate)
    self.workoutStreamConcurrency = try container.decodeIfPresent(Int.self, forKey: .workoutStreamConcurrency) ?? 3
  }
}

@_spi(VitalSDKInternals)
public struct UserSDKSyncStateResponse: Decodable {
  public let status: Status
  public let ingestionStart: Date?
  public let requestStartDate: Date?
  public let requestEndDate: Date?
  public var perDeviceActivityTs: Bool? = false
  public var expiresIn: Int?
  public var pullPreferences: TeamDataPullPreferences? = nil
  public var reportingInterval: Double?
  public var healthKitParams: UserSDKHealthKitParams? = nil
}

public enum Stage: String, Encodable {
  case daily
  case historical
}

@_spi(VitalSDKInternals)
public struct UserSDKSyncStateBody: Encodable {
  public let tzinfo: String
  public let requestStartDate: Date?
  public let requestEndDate: Date?
  public let grantedPermissions: [String]?

  public init(tzinfo: String, requestStartDate: Date? = nil, requestEndDate: Date? = nil, grantedPermissions: [String]? = nil) {
    self.tzinfo = tzinfo
    self.requestStartDate = requestStartDate
    self.requestEndDate = requestEndDate
    self.grantedPermissions = grantedPermissions
  }
}

@_spi(VitalSDKInternals)
public struct UserSDKHistoricalStageBeginBody: Encodable {
  public let rangeStart: Date
  public let rangeEnd: Date
  public let backfillType: BackfillType

  public init(rangeStart: Date, rangeEnd: Date, backfillType: BackfillType) {
    self.rangeStart = rangeStart
    self.rangeEnd = rangeEnd
    self.backfillType = backfillType
  }
}
