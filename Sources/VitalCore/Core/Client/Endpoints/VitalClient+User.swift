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

  func userConnectedSources() async throws -> [Provider] {
    let userId = try await self.client.getUserId()
    let configuration = await self.client.configuration.get()

    let path = "/\(configuration.apiVersion)/\(path)/providers/\(userId)"

    let request: Request<ProviderResponse> = .init(path: path, method: .get)
    let response = try await configuration.apiClient.send(request)
    let providers = response.value.providers.map {
      Provider(name: $0.name, slug: $0.slug, logo: $0.logo)
    }

    return providers
  }
  
  func create(
    _ payload: CreateUserRequest,
    setUserIdOnSuccess: Bool = true
  ) async throws -> CreateUserResponse {
    
    let configuration = await self.client.configuration.get()
    
    let path = "/\(configuration.apiVersion)/\(path)/"
    let request: Request<CreateUserResponse> = .init(path: path, method: .post, body: payload)
    
    configuration.logger?.info("Creating Vital's userId for id: \(payload.clientUserId, privacy: .public)")
    let value = try await configuration.apiClient.send(request).value
    
    if setUserIdOnSuccess {
      await VitalClient.setUserId(value.userId)
    }
    
    return value
  }
  
  func create(
    clientUserId: String,
    setUserIdOnSuccess: Bool = true
  ) async throws -> CreateUserResponse {
    return try await create(
      .init(clientUserId: clientUserId),
      setUserIdOnSuccess: setUserIdOnSuccess
    )
  }
  
  func deregisterProvider(provider: Provider.Slug) async throws -> Void {
    let userId = try await self.client.getUserId()
    let configuration = await self.client.configuration.get()
    
    let path = "/\(configuration.apiVersion)/\(path)/\(userId)/\(provider.rawValue)"
    
    let request: Request<Void> = .init(path: path, method: .delete)
    try await configuration.apiClient.send(request)
  }
}

