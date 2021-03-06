import Get
import Foundation

public extension VitalClient {
  class Summary {
    let client: VitalClient
    let resource = "summary"
    
    init(client: VitalClient) {
      self.client = client
    }
  }
  
  var summary: Summary {
    .init(client: self)
  }
}

public extension VitalClient.Summary {  
  func post(
    _ summaryData: SummaryData,
    stage: TaggedPayload.Stage,
    provider: Provider
  ) async throws -> Void {
    let userId = await self.client.userIdBox.getUserId()
    
    let taggedPayload = TaggedPayload(
      stage: stage,
      provider: provider,
      data: AnyEncodable(summaryData.payload)
    )
    
    let prefix: String = "/\(self.client.apiVersion)/\(self.resource)/"
    let fullPath = prefix + "\(summaryData.name)/\(userId)"
    
    let request: Request<Void> = .post(fullPath, body: taggedPayload)
    
    try await self.client.apiClient.send(request)
  }
}
