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
    provider: Provider,
    timeZone: TimeZone
  ) async throws -> Void {
    let userId = await self.client.userId.get()
    let configuration = await self.client.configuration.get()

    let taggedPayload = TaggedPayload(
      stage: stage,
      timeZone: timeZone,
      provider: provider,
      data: VitalAnyEncodable(summaryData.payload)
    )
    
    let prefix: String = "/\(configuration.apiVersion)/\(self.resource)/"
    let fullPath = prefix + "\(summaryData.name)/\(userId)"
    
    let request: Request<Void> = .post(fullPath, body: taggedPayload)
    
    try await configuration.apiClient.send(request)
  }
  
  func sleepsSummary(
    startDate: Date,
    endDate: Date? = nil
  ) async throws -> [SleepSummary] {
    let userId = await self.client.userId.get()
    let configuration = await self.client.configuration.get()
    
    let prefix: String = "/\(configuration.apiVersion)/\(self.resource)/"
    let fullPath = prefix + "sleep/\(userId)"
    let query = makeBaseDatesQuery(startDate: startDate, endDate: endDate)

    let request: Request<SleepResponse> = .get(fullPath, query: query)
    let result = try await configuration.apiClient.send(request)
                                                        
    return result.value.sleep
  }
  
  func sleepsSummaryWithStream(
    startDate: Date,
    endDate: Date? = nil
  ) async throws -> [SleepSummary] {
    let userId = await self.client.userId.get()
    let configuration = await self.client.configuration.get()
    
    let prefix: String = "/\(configuration.apiVersion)/\(self.resource)/"
    let fullPath = prefix + "sleep/\(userId)/stream"
    let query = makeBaseDatesQuery(startDate: startDate, endDate: endDate)
    
    let request: Request<SleepResponse> = .get(fullPath, query: query)
    let result = try await configuration.apiClient.send(request)
    
    return result.value.sleep
  }
  
  func activitySummary(
    startDate: Date,
    endDate: Date? = nil
  ) async throws -> [ActivitySummary] {
    let userId = await self.client.userId.get()
    let configuration = await self.client.configuration.get()
    
    let prefix: String = "/\(configuration.apiVersion)/\(self.resource)/"
    let fullPath = prefix + "activity/\(userId)"
    let query = makeBaseDatesQuery(startDate: startDate, endDate: endDate)
    
    let request: Request<ActivityResponse> = .get(fullPath, query: query)
    let result = try await configuration.apiClient.send(request)
    
    return result.value.activity
  }
}
