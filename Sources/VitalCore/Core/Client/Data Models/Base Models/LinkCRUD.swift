import Foundation

public struct CreateConnectionSourceRequest: Encodable {
  public let userId: String
  public let providerId: String?
  
  public init(userId: String, providerId: String? = nil) {
    self.userId = userId
    self.providerId = providerId
  }
}

struct CreateLinkRequest: Encodable {
  let userId: String
  let provider: String?
  let redirectUrl: String?
  
  init(
    userId: String,
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


public struct LinkEmailProviderInput: Encodable {
  public let email: String
  public let region: String?

  public init(email: String, region: String? = nil) {
    self.email = email
    self.region = region
  }
}

public struct LinkPasswordProviderInput: Encodable {
  public let username: String
  public let password: String
  public let region: String?

  public init(username: String, password: String, region: String? = nil) {
    self.username = username
    self.password = password
    self.region = region
  }
}

public struct CompletePasswordProviderMFAInput: Encodable {
  public let mfaCode: String

  public init(mfaCode: String) {
    self.mfaCode = mfaCode
  }
}

public struct LinkResponse: Decodable {
  public let state: State
  public let redirectUrl: String?
  public let error_type: String?
  public let error: String?
  public let providerMfa: ProviderMFA?

  public init(state: State, redirectUrl: String?, error_type: String?, error: String?, providerMfa: ProviderMFA?) {
    self.state = state
    self.redirectUrl = redirectUrl
    self.error_type = error_type
    self.error = error
    self.providerMfa = providerMfa
  }

  public enum State: String, RawRepresentable, Decodable {
    case success
    case error
    case pendingProviderMFA = "pending_provider_mfa"
  }

  public struct ProviderMFA: Decodable {
    public enum Method: String, RawRepresentable, Decodable {
      case sms
      case email
    }

    public let method: Method
    public let hint: String
  }
}
