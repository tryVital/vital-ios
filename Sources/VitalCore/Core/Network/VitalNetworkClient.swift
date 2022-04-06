import Foundation
import Get

public enum Environment {
  public enum Region {
    case eu
    case us
  }
  
  case dev(Region)
  case sandbox(Region)
  case production(Region)
  
  var host: String {
    switch self {
      case .dev(.eu):
        return "https://api.dev.eu.tryvital.io"
      case .dev(.us):
        return "https://api.dev.tryvital.io"
      case .sandbox(.eu):
        return "https://api.sandbox.eu.tryvital.io"
      case .sandbox(.us):
        return "https://api.sandbox.tryvital.io"
      case .production(.eu):
        return "https://api.eu.tryvital.io"
      case .production(.us):
        return "https://api.tryvital.io"
    }
  }
}

public class VitalNetworkClient {
  
  let environment: Environment
  let apiClient: APIClient
  var userId: String?
  private let apiVersion: String
  
  let refresh: () async throws -> JWT
  
  public static var shared: VitalNetworkClient {
    guard let client = Self.client else {
      fatalError("`VitalNetworkClient` hasn't been configured.")
    }
    
    return client
  }
  
  private static var client: VitalNetworkClient?
  
  private static func setInstance(client: VitalNetworkClient) {
    guard Self.client == nil else {
      fatalError("`VitalNetworkClient` is already configured.")
    }
    
    Self.client = client
  }
  
  public static func configure(
    clientId: String,
    clientSecret: String,
    environment: Environment
  ) {
    let client = VitalNetworkClient(clientId: clientId, clientSecret: clientSecret, environment: environment)
    Self.setInstance(client: client)
  }
  
  public static func setUserId(_ userId: String) {
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
    
    self.refresh = refreshToken(clientId: clientId, clientSecret: clientSecret, environment: environment)
    let apiClientDelegate = VitalNetworkClientDelegate(refresh: refresh)
    
    self.apiClient = APIClient.init(host: environment.host) { configuration in
      configuration.delegate = apiClientDelegate
      
      let encoder = JSONEncoder()
      encoder.keyEncodingStrategy = .convertToSnakeCase
      
      let decoder = JSONDecoder()
      decoder.keyDecodingStrategy = .convertFromSnakeCase
      
      configuration.encoder = encoder
      configuration.decoder = decoder
    }
  }
}
