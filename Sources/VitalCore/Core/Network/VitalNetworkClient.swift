import Foundation
import Get
import os.log

struct Credentials: Equatable, Hashable {
  let clientId: String
  let clientSecret: String
  let environment: Environment
}

public enum Environment: Equatable, Hashable, Codable {
  public enum Region: Equatable, Hashable, Codable {
    case eu
    case us
    
    var name: String {
      switch self {
        case .eu:
          return "eu"
        case .us:
          return "us"
      }
    }
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
  
  var name: String {
    switch self {
      case .dev:
        return "dev"
      case .sandbox:
        return "sandbox"
      case .production:
        return "production"
    }
  }
  
  var region: Region {
    switch self {
      case .dev(let region):
        return region
      case .sandbox(let region):
        return region
      case .production(let region):
        return region
    }
  }
}

public class VitalNetworkClient {
  
  
  
  private let keychain: VitalKeychain
  private let configuration: Configuration
  
  var logger: Logger? = nil
  var userId: UUID?
  let apiVersion: String
  let apiClient: APIClient
  let environment: Environment
  let dateFormatter: ISO8601DateFormatter
  
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
    environment: Environment,
    configuration: Configuration = .init()
  ) {
    let client = VitalNetworkClient(
      clientId: clientId,
      clientSecret: clientSecret,
      environment: environment,
      configuration: configuration
    )
    
    Self.client = client
  }
  
  public static var isSetup: Bool {
    Self.client != nil && Self.client?.userId != nil
  }
  
  public static func setUserId(_ userId: UUID) {
    VitalNetworkClient.shared.userId = userId
  }
  
  public func clean() {
    keychain.clean()
  }
  
  public init(
    clientId: String,
    clientSecret: String,
    environment: Environment,
    configuration: Configuration,
    apiVersion: String = "v2"
  ) {
    self.environment = environment
    self.apiVersion = apiVersion
    self.keychain = VitalKeychain()
    self.configuration = configuration
    
    if configuration.logsEnable {
      self.logger = Logger(subsystem: "vital", category: "vital-network-client")
    }
    
    self.logger?.info("VitalNetworkClient setup for environment \(String(describing: environment))")
    
    let basicDelegate = VitalNetworkBasicClientDelegate(logger: self.logger)
    
    
    self.dateFormatter = ISO8601DateFormatter()
    
    self.refresh = refreshToken(
      clientId: clientId,
      clientSecret: clientSecret,
      environment: environment,
      delegate: basicDelegate
    )
    
    let apiClientDelegate = VitalNetworkClientDelegate(
      refresh: refresh,
      keychain: keychain,
      environment: environment
    )
    
    let credentials = Credentials(clientId: clientId, clientSecret: clientSecret, environment: environment)
    keychain.check(credentials)
    
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

public extension VitalNetworkClient {
  struct Configuration {
    public let logsEnable: Bool
    
    public init(
      logsEnable: Bool = true
    ) {
      self.logsEnable = logsEnable
    }
  }
}
