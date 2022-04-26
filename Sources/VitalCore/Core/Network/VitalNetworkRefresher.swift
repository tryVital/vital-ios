import Get
import Foundation

private struct Payload: Encodable {
  let grantType = "client_credentials"
  let clientId: String
  let clientSecret: String
  let audience: String
}

func refreshToken(
  clientId: String,
  clientSecret: String,
  environment: Environment,
  delegate: VitalNetworkBasicClientDelegate
) -> () async throws -> JWT {
  return {
    let payload = Payload(
      clientId: clientId,
      clientSecret: clientSecret,
      audience: audience(from: environment)
    )
    
    let encoder = JSONEncoder()
    encoder.keyEncodingStrategy = .convertToSnakeCase
    
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    
    let request: Request<JWT> = .post(
      "/oauth/token",
      body: payload,
      headers: [:]
    )
    
    let baseURL = URL(string: host(from: environment))!

    var configuration = APIClient.Configuration(baseURL: baseURL)
    configuration.encoder = encoder
    configuration.decoder = decoder
    configuration.delegate = delegate
    configuration.sessionConfiguration.httpAdditionalHeaders = ["Content-Type": "application/x-www-form-urlencoded"]
    
    let client = APIClient(configuration: configuration)
    return try await client.send(request).value
  }
}


private func host(from environment: Environment) -> String {
  switch environment {
    case .production:
      return "https://auth.tryvital.io"
    case .sandbox:
      return "https://auth.sandbox.tryvital.io"
    case .dev:
      return "https://dev-vital-api.us.auth0.com"
  }
}

private func audience(from environment: Environment) -> String {
  switch environment {
    case .production:
      return "https://api.tryvital.io"
    case .sandbox:
      return "https://api.sandbox.tryvital.io"
    case .dev:
      return "https://api.tryvital.io/v1"
  }
}
