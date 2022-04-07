import Get

public extension VitalNetworkClient {
  class User {
    let client: VitalNetworkClient
    let path = "user"
    
    init(client: VitalNetworkClient) {
      self.client = client
    }
  }
  
  var user: User {
    .init(client: self)
  }
}

public extension VitalNetworkClient.User {
  func create(_ payload: CreateUserRequest) async throws -> CreateUserResponse {
    let path = "/\(self.client.apiVersion)/\(path)/"
    let request = Request<CreateUserResponse>.post(path, body: payload)
    let response = try await self.client.apiClient.send(request)
  
    return response.value
  }
}

