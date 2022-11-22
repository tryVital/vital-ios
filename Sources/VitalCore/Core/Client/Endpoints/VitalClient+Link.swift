import Foundation

public extension VitalClient {
  class Link {
    let client: VitalClient
    let path = "link"
    
    init(client: VitalClient) {
      self.client = client
    }
  }
  
  var link: Link {
    .init(client: self)
  }
}

public extension VitalClient.Link {
  
  struct ExchangedCredentials: Decodable {
    public struct Team: Decodable {
      public let name: String
      public let logoUrl: URL?
    }
    
    public let userId: UUID
    public let apiKey: String
    public let region: String
    public let environment: String
    public let team: Team
  }
  
  static func exchangeCode(code: String, environment: Environment) async throws -> ExchangedCredentials {
    let client = makeClient(environment: environment)
    let request: Request<ExchangedCredentials> = .init(path: "/v2/link/token/exchange", method: .post, query: [("code", code)])
    
    return try await client.send(request).value
  }
  
  func createLinkToken(
    provider: Provider?,
    redirectURL: String?
  ) async throws -> String {
    
    let userId = await self.client.userId.get()
    let configuration = await self.client.configuration.get()
    
    let path = "/\(configuration.apiVersion)/\(path)/token"
    
    let payload = CreateLinkRequest(userId: userId, provider: provider?.rawValue, redirectUrl: redirectURL)
    let request: Request<CreateLinkResponse> = .init(path: path, method: .post, body: payload)
    
    return try await configuration.apiClient.send(request).value.linkToken
  }
  
  func createConnectedSource(
    _ userId: UUID,
    provider: Provider
  ) async throws -> Void {
    
    let configuration = await self.client.configuration.get()
    
    let path = "/\(configuration.apiVersion)/\(path)/provider/manual/\(provider.rawValue)"
    
    let payload = CreateConnectionSourceRequest(userId: userId)
    let request: Request<Void> = .init(path: path, method: .post, body: payload)
    
    do {
      try await configuration.apiClient.send(request)
    } catch {
      guard
        let error = error as? APIError,
        case let .unacceptableStatusCode(status) = error,
        status == 409
      else {
        throw error
      }
      
      // A 409 means that there's a already a connected source, so we don't do anything.
      return
    }
  }
  
  func createConnectedSource(
    for provider: Provider
  ) async throws -> Void {
    let userId = await self.client.userId.get()
    try await createConnectedSource(userId, provider: provider)
  }
  
  func createProviderLink(
    provider: Provider? = nil,
    redirectURL: String
  ) async throws -> URL {
    let configuration = await self.client.configuration.get()
    let token = try await createLinkToken(provider: provider, redirectURL: redirectURL)
    
    let url = URL(string: "https://link.tryvital.io/")!
      .append("token", value: token)
      .append("env", value: configuration.environment.name)
      .append("region", value: configuration.environment.region.name)
      .append("isMobile", value: "True")
      
    return url
  }
  
  func createEmailProvider(
    email: String,
    provider: Provider,
    region: Environment.Region,
    redirectURL: String? = nil
  ) async throws -> CreateEmailProviderResponse {
    
    let configuration = await self.client.configuration.get()
    
    let path = "/\(configuration.apiVersion)/\(path)/provider/email/\(provider.rawValue)"
    
    let token = try await createLinkToken(provider: provider, redirectURL: redirectURL)
    
    let payload = CreateEmailProviderRequest(email: email, region: configuration.environment.region.rawValue)
    let request: Request<CreateEmailProviderResponse> = .init(path: path, method: .post, body: payload, headers: ["x-vital-link-token": token])
    
    let response = try await configuration.apiClient.send(request)
    return response.value
  }
}
