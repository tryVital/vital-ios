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
}

public enum Stage: String, Encodable {
  case daily
  case historical
}

public struct UserSDKSyncStateBody: Encodable {
  public let stage: Stage
  public let tzinfo: String
  public let requestStartDate: Date?
  public let requestEndDate: Date?
  
  public init(stage: Stage, tzinfo: String, requestStartDate: Date? = nil, requestEndDate: Date? = nil) {
    self.stage = stage
    self.tzinfo = tzinfo
    self.requestStartDate = requestStartDate
    self.requestEndDate = requestEndDate
  }
}
