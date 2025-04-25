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
  
  func createLinkToken(
    provider: Provider.Slug?,
    redirectURL: String?
  ) async throws -> String {
    
    let userId = try await self.client.getUserId()
    let configuration = await self.client.configuration.get()
    
    let path = "/\(configuration.apiVersion)/\(path)/token"
    
    let payload = CreateLinkRequest(userId: userId, provider: provider?.rawValue, redirectUrl: redirectURL)
    let request: Request<CreateLinkResponse> = .init(path: path, method: .post, body: payload)
    
    return try await configuration.apiClient.send(request).value.linkToken
  }
  
  func createConnectedSource(
    _ userId: String,
    provider: Provider.Slug,
    installationId: UUID? = nil
  ) async throws -> Void {
    
    let configuration = await self.client.configuration.get()
    
    let path = "/\(configuration.apiVersion)/\(path)/provider/manual/\(provider.rawValue)"
    
    let payload = CreateConnectionSourceRequest(userId: userId, providerId: installationId?.uuidString)
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
    for provider: Provider.Slug
  ) async throws -> Void {
    let userId = try await self.client.getUserId()
    try await createConnectedSource(userId, provider: provider)
  }
  
  func createProviderLink(
    provider: Provider.Slug? = nil,
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

  func createOAuthProvider(
    provider: Provider.Slug,
    redirectURL: String? = nil
  ) async throws -> CreateOAuthProviderResponse {
    let configuration = await self.client.configuration.get()

    let path = "/\(configuration.apiVersion)/\(path)/provider/oauth/\(provider.rawValue)"

    let token = try await createLinkToken(provider: provider, redirectURL: redirectURL)

    let request: Request<CreateOAuthProviderResponse> = .init(path: path, method: .get, headers: ["x-vital-link-token": token])

    let response = try await configuration.apiClient.send(request)
    return response.value
  }

  func linkEmailProvider(
      _ input: LinkEmailProviderInput,
    provider: Provider.Slug,
    redirectURL: String? = nil
  ) async throws -> LinkResponse {

    let configuration = await self.client.configuration.get()

    let path = "/\(configuration.apiVersion)/\(path)/provider/email/\(provider.rawValue)"

    let token = try await createLinkToken(provider: provider, redirectURL: redirectURL)

    let request: Request<LinkResponse> = .init(path: path, method: .post, body: input, headers: ["x-vital-link-token": token])

    let response = try await configuration.apiClient.send(request)
    return response.value
  }

  func linkPasswordProvider(
    _ input: LinkPasswordProviderInput,
    provider: Provider.Slug,
    redirectURL: String? = nil
  ) async throws -> (response: LinkResponse, linkToken: String) {

    let configuration = await self.client.configuration.get()

    let path = "/\(configuration.apiVersion)/\(path)/provider/password/\(provider.rawValue)"

    let token = try await createLinkToken(provider: provider, redirectURL: redirectURL)

    let request: Request<LinkResponse> = .init(path: path, method: .post, body: input, headers: ["x-vital-link-token": token])

    let response = try await configuration.apiClient.send(request)
    return (response.value, token)
  }

  func completePasswordProviderMFA(
    input: CompletePasswordProviderMFAInput,
    provider: Provider.Slug,
    linkToken: String,
    redirectURL: String? = nil
  ) async throws -> LinkResponse {

    let configuration = await self.client.configuration.get()

    let path = "/\(configuration.apiVersion)/\(path)/provider/password/\(provider.rawValue)/complete_mfa"
    let request: Request<LinkResponse> = .init(path: path, method: .post, body: input, headers: ["x-vital-link-token": linkToken])

    let response = try await configuration.apiClient.send(request)
    return response.value
  }
}
