import Get

public extension VitalNetworkClient {
  class Summary {
    let client: VitalNetworkClient
    let path = "summary"
    
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
    case glucose([QuantitySample], TaggedPayload.Stage = .daily, Provider = .manual)
    case bloodPressure([BloodPressureSample], TaggedPayload.Stage = .daily, Provider = .manual)
  }
  
  func post(resource: Resource) async throws -> Void {
    guard let userId = self.client.userId else {
      fatalError("VitalNetwork's `userId` hasn't been set. Please call `setUserId`")
    }
    
    let request: Request<Void>
    
    switch resource {
      case let .glucose(dataPoints, stage, provider):
        let taggedPayload = TaggedPayload(
          stage: stage,
          provider: provider,
          data: AnyEncodable(dataPoints)
        )
      
        let path = "/\(self.client.apiVersion)/\(path)/vitals/\(userId)/glucose"
        request = Request.post(path, body: taggedPayload)
        
      case let .bloodPressure(dataPoints, stage, provider):
        let taggedPayload = TaggedPayload(
          stage: stage,
          provider: provider,
          data: AnyEncodable(dataPoints)
        )
        
        let path = "/\(self.client.apiVersion)/\(path)/vitals/\(userId)/blood_pressure"
        request = Request.post(path, body: taggedPayload)
    }
    
    try await self.client.apiClient.send(request)
  }
}
