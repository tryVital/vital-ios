import Get
public extension VitalNetworkClient {
  class Summary {
    let client: VitalNetworkClient
    init(client: VitalNetworkClient) {
      self.client = client
    }
  }

  var summary: Summary {
    .init(client: self)
  }
}

public extension VitalNetworkClient.Summary {
  enum Resource {
    case glucose(QuantitySample)
  }
  
  func post(to resource: Resource) async throws -> Void {
    guard let userId = self.client.userId else {
      fatalError("VitalNetwork's `userId` hasn't been set. Please call `setUserId`")
    }
    
    let request: Request<Void>
    
    switch resource {
      case let .glucose(sample):
        request = Request.post("/vitals/\(userId)/glucose", body: sample)
    }
    
    try await self.client.apiClient.send(request)
  }
}
