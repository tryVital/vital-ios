import Get

public extension VitalNetworkClient {
  class Link {
    let client: VitalNetworkClient
    let path = "link"
    
    init(client: VitalNetworkClient) {
      self.client = client
    }
  }
  
  var link: Link {
    .init(client: self)
  }
}

public extension VitalNetworkClient.Link {
  
  func createConnectedSource(
    _ payload: CreateConnectionSourceRequest,
    provider: Provider
  ) async throws -> Void {
    
    let path = "/\(self.client.apiVersion)/\(path)/provider/manual/\(provider.rawValue)"
    let request = Request<Void>.post(path, body: payload)
    
    try await self.client.apiClient.send(request)
  }
  
}


