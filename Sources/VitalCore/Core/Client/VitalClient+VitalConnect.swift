import Foundation

// APIs intended for Vital Connect apps
// Does not appear under normal iOS SDK imports.

extension VitalClient {
  @_spi(VitalConnectApp)
  public static func signInWithInviteCode(_ code: String) async throws -> InviteCodeMetadata {
    let environment = try detectEnvironment(fromCode: code)
    let credentials = try await exchangeInviteCode(code: code, environment: environment)
    try await VitalClient.signIn(withRawToken: credentials.signInToken)
    return InviteCodeMetadata(
      team: credentials.team,
      userId: credentials.userId,
      environment: environment
    )
  }

  @_spi(VitalConnectApp)
  public static func revokeLegacyApiKey(_ key: String, forUserId userId: String, in environment: Environment) async throws {
    try await revokeApiKey(key, forUserId: userId, in: environment)
  }
}

@_spi(VitalConnectApp)
public struct InviteCodeMetadata {
  public let team: Team
  public let userId: String
  public let environment: Environment

  public struct Team: Decodable {
    public let name: String
    public let logoUrl: URL?
  }
}

@_spi(VitalConnectApp)
public struct VitalInviteCodeError: Error, CustomStringConvertible {
  public let description: String

  public init(_ description: String) {
    self.description = description
  }
}

internal struct ExchangedCredentials: Decodable {
  let userId: String
  let signInToken: String
  let team: InviteCodeMetadata.Team
}

internal func exchangeInviteCode(code: String, environment: Environment) async throws -> ExchangedCredentials {
  let client = makeClient(
    environment: environment,
    delegate: VitalBaseClientDelegate()
  ) { config in
    config.sessionConfiguration = .ephemeral
  }
  let request: Request<ExchangedCredentials> = .init(
    path: "/v2/link/code/exchange",
    method: .post,
    query: [("code", code), ("grant_type", "sign_in_token")]
  )

  return try await client.send(request).value
}

internal func revokeApiKey(_ key: String, forUserId userId: String, in environment: Environment) async throws {
  let client = makeClient(
    environment: environment,
    delegate: VitalClientDelegate(environment: environment, authStrategy: .apiKey(key))
  ) { config in
    config.sessionConfiguration = .ephemeral
  }
  let request: Request<Void> = .init(path: "/v2/user/\(userId)/revoke_app_api_key", method: .post)
  try await client.send(request)
}

internal func detectEnvironment(fromCode code: String) throws -> Environment {
  guard code.count >= 4 else { throw VitalInviteCodeError("Code has invalid prefix") }

  let prefix = code.prefix(4)
  let environment = String(prefix.prefix(2))
  guard let region = Environment.Region(rawValue: String(prefix.suffix(2))) else {
    throw VitalInviteCodeError("Unrecognized region")
  }

  switch environment {
  case "sk":
    return .sandbox(region)
  case "pk":
    return .production(region)
  default:
    throw VitalInviteCodeError("Unrecognized environment")
  }
}

