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
  public let userId: String
}
