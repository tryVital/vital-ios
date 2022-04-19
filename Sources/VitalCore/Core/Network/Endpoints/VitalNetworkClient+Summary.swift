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
  func post(
    resource: PostResource,
    stage: TaggedPayload.Stage,
    provider: Provider
  ) async throws -> Void {
    guard let userId = self.client.userId else {
      fatalError("VitalNetwork's `userId` hasn't been set. Please call `setUserId`")
    }
    
    guard resource.shouldSkipPost == false else {
      return
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
  for resource: PostResource,
  userId: String,
  withPrefix prefix: String
) -> String {
  switch resource {
    case .vitals(.glucose):
      return prefix + "vitals/\(userId)/glucose"
      
    case .vitals(.bloodPressure):
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
