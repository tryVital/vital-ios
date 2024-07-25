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
    provider: Provider.Slug,
    timeZone: TimeZone,
    isFinalChunk: Bool = true
  ) async throws -> Void {
    let userId = try await self.client.getUserId()
    let configuration = await self.client.configuration.get()
        
    let taggedPayload = TaggedPayload(
      stage: stage,
      timeZone: timeZone,
      provider: provider,
      data: VitalAnyEncodable(summaryData.payload),
      isFinalChunk: isFinalChunk
    )
    
    let prefix: String = "/\(configuration.apiVersion)/\(self.resource)/"
    let fullPath = prefix + "\(summaryData.name)/\(userId)"
    
    let request: Request<Void> = .init(path: fullPath, method: .post, body: taggedPayload)
    
    try await configuration.apiClient.send(request)
  }
  
  func sleepsSummary(
    startDate: Date,
    endDate: Date? = nil,
    provider: Provider.Slug? = nil
  ) async throws -> [SleepSummary] {
    let userId = try await self.client.getUserId()
    let configuration = await self.client.configuration.get()
    
    let prefix: String = "/\(configuration.apiVersion)/\(self.resource)/"
    let fullPath = prefix + "sleep/\(userId)"
    let query = makeBaseQuery(startDate: startDate, endDate: endDate, provider: provider)
    
    let request: Request<SleepResponse> = .init(path: fullPath, method: .get, query: query)
    let result = try await configuration.apiClient.send(request)
    
    return result.value.sleep
  }
  
  func sleepsRaw(
    startDate: Date,
    endDate: Date? = nil,
    provider: Provider.Slug? = nil
  ) async throws -> [AnyDecodable] {
    let userId = try await self.client.getUserId()
    let configuration = await self.client.configuration.get()
    
    let prefix: String = "/\(configuration.apiVersion)/\(self.resource)/"
    let fullPath = prefix + "sleep/\(userId)"
    let query = makeBaseQuery(startDate: startDate, endDate: endDate, provider: provider)
    
    let request: Request<SleepRawResponse> = .init(path: fullPath, method: .get, query: query)
    let result = try await configuration.apiClient.send(request)
    
    return result.value.sleep
  }

  func activitySummary(
    startDate: Date,
    endDate: Date? = nil,
    provider: Provider.Slug? = nil
  ) async throws -> [ActivitySummary] {
    let userId = try await self.client.getUserId()
    let configuration = await self.client.configuration.get()
    
    let prefix: String = "/\(configuration.apiVersion)/\(self.resource)/"
    let fullPath = prefix + "activity/\(userId)"
    let query = makeBaseQuery(startDate: startDate, endDate: endDate, provider: provider)
    
    let request: Request<ActivityResponse> = .init(path: fullPath, method: .get, query: query)
    let result = try await configuration.apiClient.send(request)
    
    return result.value.activity
  }
  
  func activityRaw(
    startDate: Date,
    endDate: Date? = nil,
    provider: Provider.Slug? = nil
  ) async throws -> [AnyDecodable] {
    let userId = try await self.client.getUserId()
    let configuration = await self.client.configuration.get()
    
    let prefix: String = "/\(configuration.apiVersion)/\(self.resource)/"
    let fullPath = prefix + "activity/\(userId)/raw"
    let query = makeBaseQuery(startDate: startDate, endDate: endDate, provider: provider)
    
    let request: Request<ActivityRawResponse> = .init(path: fullPath, method: .get, query: query)
    let result = try await configuration.apiClient.send(request)
    
    return result.value.activity
  }
  
  func workoutSummary(
    startDate: Date,
    endDate: Date? = nil,
    provider: Provider.Slug? = nil
  ) async throws -> [WorkoutSummary] {
    let userId = try await self.client.getUserId()
    let configuration = await self.client.configuration.get()
    
    let prefix: String = "/\(configuration.apiVersion)/\(self.resource)/"
    let fullPath = prefix + "workouts/\(userId)"
    let query = makeBaseQuery(startDate: startDate, endDate: endDate, provider: provider)
    
    let request: Request<WorkoutResponse> = .init(path: fullPath, method: .get, query: query)
    let result = try await configuration.apiClient.send(request)
    
    return result.value.workouts
  }
  
  func workoutRaw(
    startDate: Date,
    endDate: Date? = nil,
    provider: Provider.Slug? = nil
  ) async throws -> [AnyDecodable] {
    let userId = try await self.client.getUserId()
    let configuration = await self.client.configuration.get()
    
    let prefix: String = "/\(configuration.apiVersion)/\(self.resource)/"
    let fullPath = prefix + "workouts/\(userId)/raw"
    let query = makeBaseQuery(startDate: startDate, endDate: endDate, provider: provider)
    
    let request: Request<WorkoutRawResponse> = .init(path: fullPath, method: .get, query: query)
    let result = try await configuration.apiClient.send(request)
    
    return result.value.workouts
  }
  
  func body(
    startDate: Date,
    endDate: Date? = nil,
    provider: Provider.Slug? = nil
  ) async throws -> [BodySummary] {
    let userId = try await self.client.getUserId()
    let configuration = await self.client.configuration.get()
    
    let prefix: String = "/\(configuration.apiVersion)/\(self.resource)/"
    let fullPath = prefix + "body/\(userId)"
    let query = makeBaseQuery(startDate: startDate, endDate: endDate, provider: provider)
    
    let request: Request<BodyResponse> = .init(path: fullPath, method: .get, query: query)
    let result = try await configuration.apiClient.send(request)
    
    return result.value.body
  }
  
  func bodyRaw(
    startDate: Date,
    endDate: Date? = nil,
    provider: Provider.Slug? = nil
  ) async throws -> [AnyDecodable] {
    let userId = try await self.client.getUserId()
    let configuration = await self.client.configuration.get()
    
    let prefix: String = "/\(configuration.apiVersion)/\(self.resource)/"
    let fullPath = prefix + "body/\(userId)/raw"
    let query = makeBaseQuery(startDate: startDate, endDate: endDate, provider: provider)
    
    let request: Request<BodyRawResponse> = .init(path: fullPath, method: .get, query: query)
    let result = try await configuration.apiClient.send(request)
    
    return result.value.body
  }
}
