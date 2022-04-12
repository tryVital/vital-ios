import Foundation
import Get

public enum Environment: Equatable, Codable {
  public enum Region: Equatable, Codable {
    case eu
    case us
  }
  
  case dev(Region)
  case sandbox(Region)
  case production(Region)
  
  var host: String {
    switch self {
      case .dev(.eu):
        return "api.dev.eu.tryvital.io"
      case .dev(.us):
        return "api.dev.tryvital.io"
      case .sandbox(.eu):
        return "api.sandbox.eu.tryvital.io"
      case .sandbox(.us):
        return "api.sandbox.tryvital.io"
      case .production(.eu):
        return "api.eu.tryvital.io"
      case .production(.us):
        return "api.tryvital.io"
    }
  }
}

public class VitalNetworkClient {
  
  let environment: Environment
  let apiClient: APIClient
  var userId: UUID?
  let apiVersion: String
  
  let refresh: () async throws -> JWT
  
  public static var shared: VitalNetworkClient {
    guard let client = Self.client else {
      fatalError("`VitalNetworkClient` hasn't been configured.")
    }
    
    return client
  }
  
  private static var client: VitalNetworkClient?
  
  public static func configure(
    clientId: String,
    clientSecret: String,
    environment: Environment
  ) {
    let client = VitalNetworkClient(clientId: clientId, clientSecret: clientSecret, environment: environment)
    Self.client = client
  }
  
  public static func setUserId(_ userId: UUID) {
    VitalNetworkClient.shared.userId = userId
  }
  
  public init(
    clientId: String,
    clientSecret: String,
    environment: Environment,
    apiVersion: String = "v2"
  ) {
    self.environment = environment
    self.apiVersion = apiVersion
    
    let basicDelegate = VitalNetworkBasicClientDelegate()
    self.refresh = refreshToken(clientId: clientId, clientSecret: clientSecret, environment: environment, delegate: basicDelegate)
    let apiClientDelegate = VitalNetworkClientDelegate(refresh: refresh, environment: environment)
    
    self.apiClient = APIClient(host: environment.host) { configuration in
      configuration.delegate = apiClientDelegate
      
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
}
