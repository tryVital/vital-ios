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
      let name: String
      let logoUrl: URL?
    }
    
    public let userId: UUID
    public let apiKey: String
    public let region: String
    public let environment: String
    public let team: Team
  }
  
  static func exchangeCode(code: String, environment: Environment) async throws -> ExchangedCredentials {
    let client = makeClient(environment: environment)
    let request = Request<ExchangedCredentials>(method: "POST", url: "/v2/link/token/exchange", query: [("code", code)])
    
    return try await client.send(request).value
  }
  
  func createConnectedSource(
    _ userId: UUID,
    provider: Provider
  ) async throws -> Void {
    
    let configuration = await self.client.configuration.get()
    
    let path = "/\(configuration.apiVersion)/\(path)/provider/manual/\(provider.rawValue)"
    
    let payload = CreateConnectionSourceRequest(userId: userId)
    let request = Request<Void>.post(path, body: payload)
    
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
    
    let userId = await self.client.userId.get()
    let configuration = await self.client.configuration.get()

    let path = "/\(configuration.apiVersion)/\(path)/token"
        
    let payload = CreateLinkRequest(userId: userId, provider: provider?.rawValue, redirectUrl: redirectURL)
    let request = Request<CreateLinkResponse>.post(path, body: payload)
    
    let response = try await configuration.apiClient.send(request)
    
    let url = URL(string: "https://link.tryvital.io/")!
      .append("token", value: response.value.linkToken)
      .append("env", value: configuration.environment.name)
      .append("region", value: configuration.environment.region.name)
      .append("isMobile", value: "True")
      
    return url
  }
}
