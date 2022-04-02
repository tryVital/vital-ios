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
  
  private let environment: Environment
  private let apiClient: APIClient
  private var userId: String?
  private let apiVersion: String
  
  let refresh: () async throws -> JWT
  
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
    self.apiClient = APIClient(configuration: .init(host: environment.host, delegate: apiClientDelegate))
  }
}
