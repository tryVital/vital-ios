public extension VitalClient {
  class User {
    let client: VitalClient
    let path = "user"
    
    init(client: VitalClient) {
      self.client = client
    }
  }
  
  var user: User {
    .init(client: self)
  }
}

public extension VitalClient.User {

  func userConnections() async throws -> [UserConnection] {
    let userId = try await self.client.getUserId()
    let configuration = await self.client.configuration.get()

    let path = "/\(configuration.apiVersion)/\(path)/providers/\(userId)"

    let request: Request<ProviderResponse> = .init(path: path, method: .get)
    let response = try await configuration.apiClient.send(request)
    let providers = response.value.providers.map {
      UserConnection(
        name: $0.name,
        slug: $0.slug,
        logo: $0.logo,
        status: $0.status,
        resourceAvailability: $0.resourceAvailability
      )
    }

    return providers
  }

  @_spi(VitalSDKInternals)
  func sdkStateSync(body: UserSDKSyncStateBody) async throws -> UserSDKSyncStateResponse {
    let userId = try await self.client.getUserId()
    let configuration = await self.client.configuration.get()
    
    let path = "/\(configuration.apiVersion)/\(path)/\(userId)/sdk_sync_state/apple_health_kit"
    let request: Request<UserSDKSyncStateResponse> = .init(path: path, method: .post, body: body)
    
    let response = try await configuration.apiClient.send(request)
    
    return response.value
  }

  func deregisterProvider(provider: Provider.Slug) async throws -> Void {
    let userId = try await self.client.getUserId()
    let configuration = await self.client.configuration.get()
    
    let path = "/\(configuration.apiVersion)/\(path)/\(userId)/\(provider.rawValue)"
    
    let request: Request<Void> = .init(path: path, method: .delete)
    try await configuration.apiClient.send(request)
  }
}

