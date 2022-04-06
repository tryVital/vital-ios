import Get
public extension VitalNetworkClient {
  class Vitals {
    let client: VitalNetworkClient
    let path = "vitals"
    
    init(client: VitalNetworkClient) {
      self.client = client
    }
  }

  var vitals: Vitals {
    .init(client: self)
  }
}

public extension VitalNetworkClient.Vitals {
  enum Resource {
    case glucose(GlucosePatch, TaggedPayload.Stage, TaggedPayload.Provider = .manual)
  }
  
  func post(to resource: Resource) async throws -> Void {
    guard let userId = self.client.userId else {
      fatalError("VitalNetwork's `userId` hasn't been set. Please call `setUserId`")
    }
    
    let request: Request<Void>
    
    switch resource {
      case let .glucose(sample, stage, provider):
        let taggedPayload = TaggedPayload(
          stage: stage,
          provider: provider,
          data: .vitals(.glucose(sample))
        )
      
        request = Request.post("/\(path)/\(userId)/glucose", body: taggedPayload)
    }
    
    try await self.client.apiClient.send(request)
  }
}
