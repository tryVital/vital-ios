import Foundation

internal let legacyRestorationStateKey: String = "core_secureStorageKey"
internal let legacyUserIdKey: String = "user_secureStorageKey"

struct VitalClientRestorationState: Equatable, Codable {
  let configuration: VitalClient.Configuration
  let apiVersion: String

  // Backward compatibility with Legacy API Key mode
  let apiKey: String?
  let environment: Environment?

  // Nullable for compatibility
  let strategy: ConfigurationStrategy?

  func resolveStrategy() throws -> ConfigurationStrategy {
    if let strategy = strategy {
      return strategy
    }

    if let apiKey = apiKey, let environment = environment {
      return .apiKey(apiKey, environment)
    }

    throw DecodingError.dataCorrupted(
      .init(codingPath: [], debugDescription: "persisted SDK configuration seems corrupted")
    )
  }
}

extension VitalClient {

  static func migrateSecretsIfNeeded() throws {
    // Check for JWT sign-in state.
    if let jwtGist = VitalJWTAuth.live.getGist() {
      // Signed in as JWT User.
      try Current.startupParamsStorage.set(
        SDKStartupParams(
          userId: UUID(uuidString: jwtGist.userId)!,
          authStrategy: .jwt(jwtGist.environment)
        )
      )

      VitalLogger.core.info("migrated from JWT Gist", source: "StartupParamsMigration")
      return
    }

    // Check for VitalClientRestorationState
    let secureStorage = Current.secureStorage

    let restorationState: VitalClientRestorationState? = try secureStorage.get(key: legacyRestorationStateKey)

    if
      let state = restorationState,
      case let .apiKey(apiKey, environment) = try state.resolveStrategy(),
      let rawUserId: String = try secureStorage.get(key: legacyUserIdKey),
      let userId = UUID(uuidString: rawUserId)
    {
      try Current.startupParamsStorage.set(
        SDKStartupParams(userId: userId, authStrategy: .apiKey(apiKey, environment))
      )

      VitalLogger.core.info("migrated from API Key and User ID keychain items", source: "StartupParamsMigration")
      secureStorage.clean(key: legacyUserIdKey)
      secureStorage.clean(key: legacyRestorationStateKey)
    }
  }
}
