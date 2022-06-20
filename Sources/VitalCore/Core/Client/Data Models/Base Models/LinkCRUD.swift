import Foundation

public struct CreateConnectionSourceRequest: Encodable {
  public let userId: UUID
  public let providerId: String?
  
  public init(userId: UUID, providerId: String? = nil) {
    self.userId = userId
    self.providerId = providerId
  }
}

struct CreateLinkRequest: Encodable {
  let userId: UUID
  let provider: String?
  let redirectUrl: String
  
  init(
    userId: UUID,
    provider: String?,
    redirectUrl: String
  ) {
    self.userId = userId
    self.provider = provider
    self.redirectUrl = redirectUrl
  }
}


public struct CreateLinkResponse: Decodable {
  public let linkToken: String
  
  public init(
    linkToken: String
  ) {
    self.linkToken = linkToken
  }
}
