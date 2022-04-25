import Get
import Foundation

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
    _ userId: UUID,
    provider: Provider
  ) async throws -> Void {

    let path = "/\(self.client.apiVersion)/\(path)/provider/manual/\(provider.rawValue)"
    
    let payload = CreateConnectionSourceRequest(userId: userId)
    let request = Request<Void>.post(path, body: payload)
    
    try await self.client.apiClient.send(request)
  }
  
  func createConnectedSource(
    for provider: Provider
  ) async throws -> Void {
    
    guard let userId = self.client.userId else {
      fatalError("VitalNetwork's `userId` hasn't been set. Please call `VitalNetworkClient.setUserId`")
    }
    
    let path = "/\(self.client.apiVersion)/\(path)/provider/manual/\(provider.rawValue)"
    
    let payload = CreateConnectionSourceRequest(userId: userId)
    let request = Request<Void>.post(path, body: payload)
    
    try await self.client.apiClient.send(request)
  }
  
  func createProviderLink(
    provider: Provider? = nil,
    redirectURL: String
  ) async throws -> URL {
    
    guard let userId = self.client.userId else {
      fatalError("VitalNetwork's `userId` hasn't been set. Please call `VitalNetworkClient.setUserId`")
    }
    
    let path = "/\(self.client.apiVersion)/\(path)/token"
        
    
    let payload = CreateLinkRequest(userId: userId, provider: provider?.rawValue, redirectUrl: redirectURL)
    let request = Request<CreateLinkResponse>.post(path, body: payload)
    
    let response = try await self.client.apiClient.send(request)
    
    let url = URL(string: "https://link.tryvital.io/")!
      .append("token", value: response.value.linkToken)
      .append("env", value: self.client.environment.name)
      .append("region", value: self.client.environment.region.name)
      .append("mobile", value: "true")
      
    return url
  }
}
