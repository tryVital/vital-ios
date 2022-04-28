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
    let fullPath = prefix + "\(summaryData.name)/\(userId)"
        
    let request: Request<Void> = .post(fullPath, body: taggedPayload)
    
    self.client.logger?.info("Posting data for: \(summaryData.name)")
    try await self.client.apiClient.send(request)
  }
}
