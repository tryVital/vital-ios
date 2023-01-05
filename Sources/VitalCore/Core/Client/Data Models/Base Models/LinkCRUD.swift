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
  let redirectUrl: String?
  
  init(
    userId: UUID,
    provider: String?,
    redirectUrl: String?
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

public struct CreateOAuthProviderResponse: Decodable {
  public let name: String
  public let slug: String
  public let logo: String
  public let description: String
  public let oauthUrl: URL
  public let authType: String
  public let id: Int
}


public struct CreateEmailProviderRequest: Encodable {
  public let email: String
  public let region: String?
  
  public init(
    email: String,
    region: String?
  ) {
    self.email = email
    self.region = region
  }
}

public struct CreateEmailProviderResponse: Decodable {
  public let success: Bool
  public let redirectUrl: String?
  
  public init(
    success: Bool,
    redirectUrl: String?
  ) {
    self.success = success
    self.redirectUrl = redirectUrl
  }
}

