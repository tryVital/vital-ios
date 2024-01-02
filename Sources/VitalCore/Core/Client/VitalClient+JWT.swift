extension VitalClient {
  /// Obtain the signed-in user's access token for Vital API requests.
  ///
  /// - precondition: The user was signed-in using Vital Sign-In Token.
  public static func getAccessToken() async throws -> String {
    let status = VitalClient.status
    if !status.contains(.configured) {
      throw VitalAccessTokenError("Cannot get access token: SDK is not yet configured")
    }
    if !status.contains(.useSignInToken) {
      throw VitalAccessTokenError("Cannot get access token: User is not signed in with Vital Sign-In Token")
    }

    return try await VitalJWTAuth.live.withAccessToken { $0 }
  }

  /// Refresh the signed-in user's access token.
  ///
  /// - precondition: The user was signed-in using Vital Sign-In Token.
  public static func refreshToken() async throws {
    let status = VitalClient.status
    if !status.contains(.configured) {
      throw VitalAccessTokenError("Cannot get access token: SDK is not yet configured")
    }
    if !status.contains(.useSignInToken) {
      throw VitalAccessTokenError("Cannot get access token: User is not signed in with Vital Sign-In Token")
    }

    return try await VitalJWTAuth.live.refreshToken()
  }
}

public struct VitalAccessTokenError: Error, CustomStringConvertible {
  public let description: String

  public init(_ description: String) {
    self.description = description
  }
}

