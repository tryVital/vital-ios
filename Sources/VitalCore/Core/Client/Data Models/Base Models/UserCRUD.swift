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

public enum Status: String, Decodable {
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
public struct UserSDKSyncStateResponse: Decodable {
  public let status: Status
  public let ingestionStart: Date?
  public let requestStartDate: Date?
  public let requestEndDate: Date?
  public var perDeviceActivityTs: Bool? = false
  public var expiresIn: Int?
  public var pullPreferences: TeamDataPullPreferences? = nil
}

public enum Stage: String, Encodable {
  case daily
  case historical
}

public struct UserSDKSyncStateBody: Encodable {
  public let tzinfo: String
  public let requestStartDate: Date?
  public let requestEndDate: Date?

  public init(tzinfo: String, requestStartDate: Date? = nil, requestEndDate: Date? = nil) {
    self.tzinfo = tzinfo
    self.requestStartDate = requestStartDate
    self.requestEndDate = requestEndDate
  }
}
