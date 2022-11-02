import Foundation


func makeClient(
  environment: Environment,
  delegate: APIClientDelegate = VitalBaseClientDelegate(),
  updateAPIClientConfiguration: (inout APIClient.Configuration) -> Void = { _ in }
) -> APIClient {
  
  return  APIClient(baseURL: URL(string: environment.host)!) { configuration in
    configuration.delegate = delegate
    
    updateAPIClientConfiguration(&configuration)
    
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    encoder.keyEncodingStrategy = .convertToSnakeCase
    
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    decoder.dateDecodingStrategy = .iso8601
    
    configuration.encoder = encoder
    configuration.decoder = decoder
  }
}
