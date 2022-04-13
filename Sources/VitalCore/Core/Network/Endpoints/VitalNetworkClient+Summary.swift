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
    case profile(ProfilePatch)
    case body(BodyPatch)
    case activity(ActivityPatch)
    case sleep(SleepPatch)
    case workout(WorkoutPatch)
    case glucose([QuantitySample])
    case bloodPressure([BloodPressureSample])
  }
  
  func post(resource: Resource, stage: TaggedPayload.Stage?, provider: Provider) async throws -> Void {
    guard let userId = self.client.userId else {
      fatalError("VitalNetwork's `userId` hasn't been set. Please call `setUserId`")
    }
    
    let request: Request<Void>
    let stage = stage ?? .daily
    
    switch resource {
      case let .glucose(dataPoints):
        let taggedPayload = TaggedPayload(
          stage: stage,
          provider: provider,
          data: AnyEncodable(dataPoints)
        )
      
        let path = "/\(self.client.apiVersion)/\(path)/vitals/\(userId)/glucose"
        request = Request.post(path, body: taggedPayload)
        
      case let .bloodPressure(dataPoints):
        let taggedPayload = TaggedPayload(
          stage: stage,
          provider: provider,
          data: AnyEncodable(dataPoints)
        )
        
        let path = "/\(self.client.apiVersion)/\(path)/vitals/\(userId)/blood_pressure"
        request = Request.post(path, body: taggedPayload)
        
      case let .profile(patch):
        return
        
      case let .body(patch):
        return
        
      case let .activity(patch):
        return
        
      case let .sleep(patch):
        return
        
      case let .workout(patch):
        return
    }
    
    try await self.client.apiClient.send(request)
  }
}
