import Get
import Foundation

public extension VitalNetworkClient {
  class Summary {
    let client: VitalNetworkClient
    let resource = "summary"
    
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
    
    var payload: Encodable {
      switch self {
        case let .profile(patch):
          return patch
        case let .body(patch):
          return patch
        case let .activity(patch):
          return patch
        case let .sleep(patch):
          return patch
        case let .workout(patch):
          return patch
        case let .glucose(dataPoints):
          return dataPoints
        case let .bloodPressure(dataPoints):
          return dataPoints
      }
    }
  }
  
  func post(
    resource: Resource,
    stage: TaggedPayload.Stage,
    provider: Provider
  ) async throws -> Void {
    guard let userId = self.client.userId else {
      fatalError("VitalNetwork's `userId` hasn't been set. Please call `setUserId`")
    }
        
    let taggedPayload = TaggedPayload(
      stage: stage,
      provider: provider,
      data: AnyEncodable(resource.payload)
    )
    
    let prefix: String = "/\(self.client.apiVersion)/\(self.resource)/"
    let fullPath = makePath(for: resource, userId: userId.uuidString, withPrefix: prefix)
        
    let request: Request<Void> = .post(fullPath, body: taggedPayload)
    try await self.client.apiClient.send(request)
  }
}

func makePath(
  for resource: VitalNetworkClient.Summary.Resource,
  userId: String,
  withPrefix prefix: String
) -> String {
  switch resource {
    case .glucose:
      return prefix + "vitals/\(userId)/glucose"
      
    case .bloodPressure:
      return prefix + "vitals/\(userId)/blood_pressure"
      
    case .profile:
      return prefix + "profile/\(userId)"
      
    case .body:
      return prefix + "body/\(userId)"
      
    case .activity:
      return prefix + "activity/\(userId)"
      
    case .sleep:
      return prefix + "sleep/\(userId)"
      
    case .workout:
      return prefix + "workout/\(userId)"
  }
}
