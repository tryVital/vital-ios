import Foundation
import Mocker

@testable import VitalCore

func makeMockApiClient(environment: Environment, apiKey: String) -> APIClient {
  
  let apiClientDelegate = VitalClientDelegate(
    environment: environment,
    apiKey: apiKey
  )
  
  let url = URL(string: environment.host)!
  let apiClient = APIClient(baseURL: url) { configuration in
    configuration.delegate = apiClientDelegate
    
    configuration.sessionConfiguration.protocolClasses = [MockingURLProtocol.self]
    
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    encoder.keyEncodingStrategy = .convertToSnakeCase
    
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    decoder.dateDecodingStrategy = .iso8601
    
    configuration.encoder = encoder
    configuration.decoder = decoder
  }
  
  return apiClient
}
