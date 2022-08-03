import Foundation

public enum SimpleTimeSeriesResource {
  case glucose
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
    provider: Provider
  ) async throws -> Void {
    let userId = await self.client.userId.get()
    let configuration = await self.client.configuration.get()

    let taggedPayload = TaggedPayload(
      stage: stage,
      provider: provider,
      data: VitalAnyEncodable(timeSeriesData.payload)
    )
    
    let fullPath: String = await makePath(for: timeSeriesData.name, userId: userId.uuidString)
    let request: Request<Void> = .post(fullPath, body: taggedPayload)
    
    configuration.logger?.info("Posting TimeSeries data for: \(timeSeriesData.name)")
    try await configuration.apiClient.send(request)
  }
  
  func get(
    resource: SimpleTimeSeriesResource,
    provider: Provider? = nil,
    startDate: Date,
    endDate: Date? = nil
  ) async throws -> [TimeSeriesDataPoint] {
    
    let userId = await self.client.userId.get()
    let configuration = await self.client.configuration.get()

    let query = makeQuery(startDate: startDate, endDate: endDate)
    
    switch resource {
      case .glucose:
        let path = await makePath(for: "glucose", userId: userId.uuidString)

        let request: Request<[TimeSeriesDataPoint]> = .get(path, query: query, headers: [:])
        let response = try await configuration.apiClient.send(request)
        return response.value
    }
  }
  
  func getBloodPressure(
    provider: Provider? = nil,
    startDate: Date,
    endDate: Date? = nil
  ) async throws -> [BloodPressureDataPoint] {
    
    let userId = await self.client.userId.get()
    let configuration = await self.client.configuration.get()

    let path = await makePath(for: "blood_pressure", userId: userId.uuidString)
    let query = makeQuery(startDate: startDate, endDate: endDate)
    
    let request: Request<[BloodPressureDataPoint]> = .get(path, query: query, headers: [:])
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
    
    let startDateString = self.client.dateFormatter.string(from: startDate)
    
    var query: [(String, String?)] = [("start_date", startDateString)]
    
    if let endDate = endDate {
      let endDateString = self.client.dateFormatter.string(from: endDate)
      query.append(("end_date", endDateString))
    }
    
    return query
  }
}
