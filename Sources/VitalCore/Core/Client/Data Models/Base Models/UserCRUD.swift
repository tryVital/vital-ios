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

public struct UserSDKSyncStateResponse: Decodable {
  public let status: Status
  public let requestStartDate: Date?
  public let requestEndDate: Date?
  public var perDeviceActivityTS: Bool = false
  public var expiresIn: Int = 14400

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.status = try container.decode(Status.self, forKey: .status)
    self.requestStartDate = try container.decodeIfPresent(Date.self, forKey: .requestStartDate)
    self.requestEndDate = try container.decodeIfPresent(Date.self, forKey: .requestEndDate)
    self.perDeviceActivityTS = try container.decodeIfPresent(Bool.self, forKey: .perDeviceActivityTS) ?? false
    self.expiresIn = try container.decodeIfPresent(Int.self, forKey: .expiresIn) ?? 14400
  }

  enum CodingKeys: String, CodingKey {
    case status = "status"
    case requestStartDate = "request_start_date"
    case requestEndDate = "request_end_date"
    case perDeviceActivityTS = "per_device_activity_ts"
    case expiresIn = "expires_in"
  }
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
