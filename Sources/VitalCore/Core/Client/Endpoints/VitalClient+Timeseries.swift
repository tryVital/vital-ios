import Foundation

public enum ScalarTimeseriesResource: String {
  case glucose = "glucose"
  case heartRate = "heartrate"
  case bloodOxygen = "blood_oxygen"
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
    let userId = try await self.client.getUserId()
    let configuration = await self.client.configuration.get()

    let taggedPayload = TaggedPayload(
      stage: stage,
      timeZone: timeZone,
      provider: provider,
      data: VitalAnyEncodable(timeSeriesData.payload)
    )
    
    let fullPath = makePath(for: timeSeriesData.name, userId: userId)
    let request: Request<Void> = .init(path: fullPath, method: .post, body: taggedPayload)
    
    VitalLogger.core.info("Posting TimeSeries data for: \(timeSeriesData.name)")
    try await configuration.apiClient.send(request)
  }
  
  func get(
    resource: ScalarTimeseriesResource,
    startDate: Date,
    endDate: Date? = nil,
    provider: Provider.Slug? = nil,
    nextCursor: String? = nil
  ) async throws -> GroupedSamplesResponse<ScalarSample> {

    let userId = try await self.client.getUserId()
    let configuration = await self.client.configuration.get()

    let query = makeBaseQuery(startDate: startDate, endDate: endDate, provider: provider, nextCursor: nextCursor)
    let path = resource.rawValue

    let fullPath = makePath(for: path, userId: userId).append("grouped")

    let request: Request<GroupedSamplesResponse<ScalarSample>> = .init(path: fullPath, method: .get, query: query)

    let response = try await configuration.apiClient.send(request)
    return response.value
  }
  
  func getBloodPressure(
    startDate: Date,
    endDate: Date? = nil,
    provider: Provider.Slug? = nil,
    nextCursor: String? = nil
  ) async throws -> GroupedSamplesResponse<BloodPressureSample> {

    let userId = try await self.client.getUserId()
    let configuration = await self.client.configuration.get()

    let path = makePath(for: "blood_pressure", userId: userId).append("grouped")
    let query = makeBaseQuery(startDate: startDate, endDate: endDate, provider: provider, nextCursor: nextCursor)

    let request: Request<GroupedSamplesResponse<BloodPressureSample>> = .init(path: path, method: .get, query: query)
    let response = try await configuration.apiClient.send(request)
    
    return response.value
  }
  
  func makePath(
    for resource: String,
    userId: String
  ) -> String {
    return "/v2/timeseries/\(userId)/\(resource)"
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
