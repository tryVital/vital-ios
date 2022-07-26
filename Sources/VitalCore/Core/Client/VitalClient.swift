import Foundation
import os.log

struct Credentials: Equatable, Hashable {
  let apiKey: String
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

public class VitalClient {
  
  private let configuration: Configuration
  private let storage: VitalCoreStorage
  
  var logger: Logger? = nil
  var userIdBox: UserIdBox = .init()
  let apiVersion: String
  let apiClient: APIClient
  
  let environment: Environment
  let dateFormatter = ISO8601DateFormatter()
  
  public static var shared: VitalClient {
    guard let client = Self.client else {
      fatalError("`VitalClient` hasn't been configured.")
    }
    
    return client
  }
  
  private static var client: VitalClient?
  
  public static func configure(
    apiKey: String,
    environment: Environment,
    configuration: Configuration = .init()
  ) {
    let client = VitalClient(
      apiKey: apiKey,
      environment: environment,
      configuration: configuration
    )
    
    Self.client = client
  }
  
  init(
    apiKey: String,
    environment: Environment,
    configuration: Configuration,
    storage: VitalCoreStorage = .init(),
    apiVersion: String = "v2"
  ) {
    self.environment = environment
    self.configuration = configuration
    self.storage = storage
    self.apiVersion = apiVersion
    
    if configuration.logsEnable {
      self.logger = Logger(subsystem: "vital", category: "vital-network-client")
    }
    
    self.logger?.info("VitalClient setup for environment \(String(describing: environment))")
    
    let apiClientDelegate = VitalClientDelegate(
      environment: environment,
      logger: logger,
      apiKey: apiKey
    )
    
    self.apiClient = APIClient(baseURL: URL(string: environment.host)!) { configuration in
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
  
  public static var isSetup: Bool {
    Self.client != nil
  }
  
  public static func setUserId(_ userId: UUID) {
    Task.detached(priority: .high) {
      await VitalClient.shared.userIdBox.set(userId: userId)
    }
  }
  
  public func checkConnectedSource(for provider: Provider) async throws {
    let userId = await userIdBox.getUserId()
    
    guard storage.isConnectedSourceStored(for: userId, with: provider) == false else {
      return
    }
    
    let connectedSources = try await self.user.userConnectedSources()
    if connectedSources.contains(provider) == false {
      try await self.link.createConnectedSource(userId, provider: provider)
    }
    
    storage.storeConnectedSource(for: userId, with: provider)
  }
  
  public func cleanUp() {
    Task.detached(priority: .high) {
      /// Here we remove the following:
      /// 1) Anchor values we are storing for each `HKSampleType`.
      /// 2) Stage for each `HKSampleType`.
      ///
      /// We might be able to derive 2) from 1)?
      UserDefaults.standard.removePersistentDomain(forName: "tryVital")
      
      await self.userIdBox.clean()
    }
  }
}

public extension VitalClient {
  struct Configuration {
    public let logsEnable: Bool
    
    public init(
      logsEnable: Bool = true
    ) {
      self.logsEnable = logsEnable
    }
  }
}
