import Foundation

public enum VitalJWTAuthError: Error, Hashable {
  case notSignedIn
  case reauthenticationNeeded
  case tokenRefreshFailure
}

internal struct VitalJWTAuthNeedsRefresh: Error {}

internal actor VitalJWTAuth {
  private static let keychainKey = "vital_jwt_auth"

  private let storage: VitalSecureStorage
  private let session: URLSession

  private let parkingLot = ParkingLot()
  private var cachedRecord: VitalJWTAuthRecord? = nil

  init(
    storage: VitalSecureStorage = VitalSecureStorage(keychain: .live)
  ) {
    self.storage = storage
    self.session = URLSession(configuration: .ephemeral)
  }

  func signIn() async throws {
    // TODO: Perform the token exchange API call
  }

  func signOut() async throws {
    try setRecord(nil)
  }

  /// If the action encounters 401 Unauthorized, throw `VitalJWTAuthNeedsRefresh` to initiate
  /// the token refresh flow.
  func withAccessToken<Result>(action: (String) async throws -> Result) async throws -> Result {
    /// When token refresh flow is ongoing, the ParkingLot is enabled and the call will suspend
    /// until the flow completes.
    /// Otherwise, the call will return immediately when the ParkingLot is disabled.
    try await parkingLot.parkIfNeeded()

    guard let record = try getRecord() else {
      throw VitalJWTAuthError.notSignedIn
    }

    do {
      guard !record.isExpired() else {
        throw VitalJWTAuthNeedsRefresh()
      }

      return try await action(record.accessToken)

    } catch is VitalJWTAuthNeedsRefresh {
      // Try to start refresh
      try await refreshToken()

      // Retry
      return try await withAccessToken(action: action)
    }
  }

  /// Start a token refresh flow, or wait for the started flow to complete.
  private func refreshToken() async throws {
    try await withTaskCancellationHandler {
      try Task.checkCancellation()

      guard parkingLot.tryTo(.enable) else {
        // Another task has started the refresh flow.
        // Join the ParkingLot to wait for the token refresh completion.
        try await parkingLot.parkIfNeeded()
        return
      }

      defer { _ = parkingLot.tryTo(.disable) }

      guard let record = try getRecord() else {
        throw VitalJWTAuthError.notSignedIn
      }

      var components = URLComponents(string: "https://securetoken.googleapis.com/v1/token")!
      components.queryItems = [URLQueryItem(name: "key", value: record.publicApiKey)]
      var request = URLRequest(url: components.url!)

      request.httpMethod = "POST"
      request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
      let encodedToken = record.refreshToken.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!
      request.httpBody = "grant_type=refresh_token&refresh_token=\(encodedToken)".data(using: .utf8)

      let (data, response) = try await session.data(for: request)
      let httpResponse = response as! HTTPURLResponse

      switch httpResponse.statusCode {
      case 200 ... 299:
        let decoder = JSONDecoder()
        let refreshResponse = try decoder.decode(FirebaseTokenRefreshResponse.self, from: data)

        var newRecord = record
        newRecord.refreshToken = refreshResponse.refreshToken
        newRecord.accessToken = refreshResponse.idToken
        newRecord.expiry = Date().addingTimeInterval(Double(refreshResponse.expiresIn) ?? 3600)

        try setRecord(newRecord)

      case 401:
        throw VitalJWTAuthError.reauthenticationNeeded

      default:
        throw VitalJWTAuthError.tokenRefreshFailure
      }

    } onCancel: {
      _ = parkingLot.tryTo(.disable)
    }
  }

  private func getRecord() throws -> VitalJWTAuthRecord? {
    if let record = cachedRecord {
      return record
    }

    // Backfill from keychain
    let record: VitalJWTAuthRecord? = try storage.get(key: Self.keychainKey)
    self.cachedRecord = record
    return record
  }

  private func setRecord(_ record: VitalJWTAuthRecord?) throws {
    defer { self.cachedRecord = record }
    if let record = record {
      try storage.set(value: record, key: Self.keychainKey)
    } else {
      storage.clean(key: Self.keychainKey)
    }
  }
}

private struct VitalJWTAuthRecord: Codable {
  let userId: String
  let teamId: String
  let publicApiKey: String
  var accessToken: String
  var refreshToken: String
  var expiry: Date

  func isExpired(now: Date = Date()) -> Bool {
    expiry <= now
  }
}

private struct FirebaseTokenRefreshResponse: Codable {
  let expiresIn: String
  let refreshToken: String
  let idToken: String

  enum CodingKeys: String, CodingKey {
    case expiresIn = "expires_in"
    case refreshToken = "refresh_token"
    case idToken = "id_token"
  }
}

/// A parking lot that holds waiting callers for token refresh flow to complete.
private final class ParkingLot: @unchecked Sendable {
  enum State: Sendable {
    case mustPark([UUID: CheckedContinuation<Void, Never>] = [:])
    case disabled
  }

  enum Action {
    case enable
    case disable
  }

  private var state: State = .disabled
  private var lock = NSLock()

  func tryTo(_ action: Action) -> Bool {
    let (callersToRelease, hasTransitioned): ([CheckedContinuation<Void, Never>], Bool) = lock.withLock {
      switch (self.state, action) {
      case (.disabled, .enable):
        self.state = .mustPark()
        return ([], true)

      case (let .mustPark(parked), .disable):
        self.state = .disabled
        return (Array(parked.values), true)

      case (.mustPark, .enable), (.disabled, .disable):
        return ([], false)
      }
    }

    if !callersToRelease.isEmpty {
      Task {
        await withTaskGroup(of: Void.self) { group in
          for continuation in callersToRelease {
            group.addTask { continuation.resume() }
          }
        }
      }
    }

    return hasTransitioned
  }

  func parkIfNeeded() async throws {
    let ticket = UUID()

    return try await withTaskCancellationHandler {
      try Task.checkCancellation()

      return await withCheckedContinuation { continuation in
        let mustPark = lock.withLock {
          switch self.state {
          case let .mustPark(parked):
            var parked = parked
            parked[ticket] = continuation
            self.state = .mustPark(parked)
            return true

          case .disabled:
            return false
          }
        }

        if mustPark == false {
          continuation.resume()
        }
      }

    } onCancel: {
      lock.withLock {
        switch self.state {
        case let .mustPark(parked):
          var parked = parked
          parked.removeValue(forKey: ticket)
          self.state = .mustPark(parked)
        case .disabled:
          break
        }
      }
    }
  }
}
