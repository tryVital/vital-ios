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
    _ summaryData: SummaryData,
    stage: TaggedPayload.Stage,
    provider: Provider
  ) async throws -> Void {
    guard let userId = self.client.userId else {
      fatalError("VitalNetwork's `userId` hasn't been set. Please call `setUserId`")
    }
        
    let taggedPayload = TaggedPayload(
      stage: stage,
      provider: provider,
      data: AnyEncodable(summaryData.payload)
    )
    
    
    let prefix: String = "/\(self.client.apiVersion)/\(self.resource)/"
    let fullPath = makePath(for: summaryData, userId: userId.uuidString, withPrefix: prefix)
        
    let request: Request<Void> = .post(fullPath, body: taggedPayload)
    
    self.client.logger?.info("Posting data for: \(summaryData.logDescription)")
    try await self.client.apiClient.send(request)
  }
}

func makePath(
  for summaryData: SummaryData,
  userId: String,
  withPrefix prefix: String
) -> String {
  switch summaryData {
    case .profile:
      return prefix + "profile/\(userId)"
      
    case .body:
      return prefix + "body/\(userId)"
      
    case .activity:
      return prefix + "activity/\(userId)"
      
    case .sleep:
      return prefix + "sleep/\(userId)"
      
    case .workout:
      return prefix + "workouts/\(userId)"
  }
}
