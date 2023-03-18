import Foundation

public enum SimpleTimeSeriesResource {
  case glucose
  case heartRate
  
  var toPath: String {
    switch self {
      case .heartRate:
        return "heartrate"
      case .glucose:
        return "glucose"
    }
  }
}

public extension VitalClient {
  class TimeSeries {
    let client: VitalClient
    let resource = "timeseries"
    
    init(client: VitalClient) {
      self.client = client
    }
  }
  
  var timeSeries: TimeSeries {
    .init(client: self)
  }
}

public extension VitalClient.TimeSeries {
  func post(
    _ timeSeriesData: TimeSeriesData,
    stage: TaggedPayload.Stage,
    provider: Provider.Slug,
    timeZone: TimeZone
  ) async throws -> Void {
    let userId = await self.client.userId.get()
    let configuration = await self.client.configuration.get()

    let taggedPayload = TaggedPayload(
      stage: stage,
      timeZone: timeZone,
      provider: provider,
      data: VitalAnyEncodable(timeSeriesData.payload)
    )
    
    let fullPath: String = await makePath(for: timeSeriesData.name, userId: userId.uuidString)
    let request: Request<Void> = .init(path: fullPath, method: .post, body: taggedPayload)
    
    configuration.logger?.info("Posting TimeSeries data for: \(timeSeriesData.name)")
    try await configuration.apiClient.send(request)
  }
  
  func get(
    resource: SimpleTimeSeriesResource,
    startDate: Date,
    endDate: Date? = nil,
    provider: Provider.Slug? = nil
  ) async throws -> [TimeSeriesDataPoint] {
    
    let userId = await self.client.userId.get()
    let configuration = await self.client.configuration.get()

    let query = makeBaseQuery(startDate: startDate, endDate: endDate, provider: provider)
    let path = resource.toPath
    
    let fullPath = await makePath(for: path, userId: userId.uuidString)
    
    let request: Request<[TimeSeriesDataPoint]> = .init(path: fullPath, method: .get, query: query)
    
    let response = try await configuration.apiClient.send(request)
    return response.value
  }
  
  func getBloodPressure(
    startDate: Date,
    endDate: Date? = nil,
    provider: Provider.Slug? = nil
  ) async throws -> [BloodPressureDataPoint] {
    
    let userId = await self.client.userId.get()
    let configuration = await self.client.configuration.get()

    let path = await makePath(for: "blood_pressure", userId: userId.uuidString)
    let query = makeBaseQuery(startDate: startDate, endDate: endDate, provider: provider)
    
    let request: Request<[BloodPressureDataPoint]> = .init(path: path, method: .get, query: query)
    let response = try await configuration.apiClient.send(request)
    
    return response.value
  }
  
  func makePath(
    for resource: String,
    userId: String
  ) async -> String {

    let configuration = await client.configuration.get()

    let prefix: String = "/\(configuration.apiVersion)"
      .append(self.resource)
      .append(userId)

    return prefix.append(resource)
  }
  
  func makeQuery(
    startDate: Date,
    endDate: Date?
  ) -> [(String, String?)] {
    
    let formatter = ISO8601DateFormatter()
    let startDateString = formatter.string(from: startDate)
    
    var query: [(String, String?)] = [("start_date", startDateString)]
    
    if let endDate = endDate {
      let endDateString = formatter.string(from: endDate)
      query.append(("end_date", endDateString))
    }
    
    return query
  }
}
