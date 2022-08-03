import Foundation
import os.log

struct Credentials: Equatable, Hashable {
  let apiKey: String
  let environment: Environment
}

struct VitalCoreConfiguration {
  var logger: Logger? = nil
  let apiVersion: String
  let apiClient: APIClient
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
  
  private let storage: VitalCoreStorage = .init()
  let dateFormatter = ISO8601DateFormatter()
  
  var configuration: ProtectedBox<VitalCoreConfiguration> = .init()
  var userId: ProtectedBox<UUID> = .init()
  
  public static var shared: VitalClient {
    return client
  }
  
  private static var client: VitalClient = .init()
  
  public static func configure(
    apiKey: String,
    environment: Environment,
    configuration: Configuration = .init()
  ) {
    Task.detached(priority: .high) {
      let client = await VitalClient(
        apiKey: apiKey,
        environment: environment,
        configuration: configuration
      )
      
      Self.client = client
    }
  }
  
  init() {
    /// Empty initialisation, before VitalClient is actually setup
  }
  
  init(
    apiKey: String,
    environment: Environment,
    configuration: Configuration,
    storage: VitalCoreStorage = .init(),
    apiVersion: String = "v2"
  ) async {
    var logger: Logger?
    
    if configuration.logsEnable {
      logger = Logger(subsystem: "vital", category: "vital-network-client")
    }
    
    logger?.info("VitalClient setup for environment \(String(describing: environment))")
    
    let apiClientDelegate = VitalClientDelegate(
      environment: environment,
      logger: logger,
      apiKey: apiKey
    )
    
    let apiClient = APIClient(baseURL: URL(string: environment.host)!) { configuration in
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
    
    let configuration = VitalCoreConfiguration(
      logger: logger,
      apiVersion: apiVersion,
      apiClient: apiClient,
      environment: environment
    )
    
    await self.configuration.set(value: configuration)
  }
  
  public static func setUserId(_ userId: UUID) {
    Task.detached(priority: .high) {
      await VitalClient.shared.userId.set(value: userId)
    }
  }
  
  public func checkConnectedSource(for provider: Provider) async throws {
    let userId = await userId.get()
    
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
      
      await self.userId.clean()
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
