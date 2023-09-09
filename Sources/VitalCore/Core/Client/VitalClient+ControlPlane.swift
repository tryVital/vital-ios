import Foundation

extension VitalClient {
  public struct ControlPlane {
    let client: APIClient

    /// Create a Vital user, given a unique user identifier in your domain.
    ///
    /// - returns: A Vital User ID (UUID) and the supplied unique user identifier.
    public func createUser(clientUserId: String) async throws -> CreateUserResponse {
      let input = CreateUserRequest(clientUserId: clientUserId)
      let request = Request<CreateUserResponse>(path: "/v2/user", method: .post, body: input)
      let value = try await client.send(request).value
      return value
    }

    /// Create a Vital Sign-In Token.
    ///
    /// - returns: The Vital Sign-In Token, and the Vital User ID (UUID).
    public func createSignInToken(userId: UUID) async throws -> CreateSignInTokenResponse {
      let request = Request<CreateSignInTokenResponse>(path: "/v2/user/\(userId.uuidString)/sign_in_token", method: .post, body: nil)
      let value = try await client.send(request).value
      return value
    }
  }

  /// Control plane API calls which can be made via the API Key without having to configure the SDK.
  ///
  /// - warning: If you use Vital Sign-In Token, the API Key should be a server-side secret, and these calls generally
  /// should be done by your backend services after authenticating the app user.
  /// These control plane methods are only intended for early prototyping in Vital Sandbox, and customers sticking to the Legacy
  /// API Key mode.
  public static func controlPlane(
    apiKey: String,
    environment: Environment
  ) -> ControlPlane {
    ControlPlane(
      client: makeClient(
        environment: environment,
        delegate: VitalClientDelegate(environment: environment, authStrategy: .apiKey(apiKey))
      ) { config in
        config.sessionConfiguration = .ephemeral
      }
    )
  }
}
