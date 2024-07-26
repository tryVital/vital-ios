import Foundation

internal protocol GistKey<T> {
  associatedtype T: Codable
  static var identifier: String { get }
}

/// GistStorage stores data to the Application Support directory with `.noFileProtection`.
/// This ensures that the gist data would remain accessible before device first unlock.
/// 
/// Certain SDK queries (e.g., `VitalClient.status`) are backed by Gist Storage, since the host app
/// may be pre-warmed in iOS 15+ and therefore may unintentionally query the SDK during this post reboot to device
/// first unlock time window.
internal final class VitalGistStorage: @unchecked Sendable {
  private static let directoryURL = {
    let applicationSupport: URL

    if #available(iOS 16.0, *) {
      applicationSupport = URL.applicationSupportDirectory
    } else {
      applicationSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    }

    return applicationSupport.appendingPathComponent("io.tryvital.VitalCore", isDirectory: true)
  }()

  private static func fileURL(forKey key: String) -> URL {
    Self.directoryURL.appendingPathComponent("\(key).json", isDirectory: false)
  }

  private var state: [ObjectIdentifier: State] = [:]
  private let lock = NSLock()

  static let shared = VitalGistStorage()

  func get<Key: GistKey>(_ key: Key.Type) -> Key.T? {
    let typeKey = ObjectIdentifier(key)

    do {
      return try lock.withLock { () -> Key.T? in
        switch self.state[typeKey, default: .uninitialized] {
        case let .hasGist(gist):
          return (gist as! Key.T)

        case .noGist:
          return nil

        case .uninitialized:
          do {
            // Hydrate gist from disk
            let data = try Data(contentsOf: Self.fileURL(forKey: key.identifier))
            let gist = try JSONDecoder().decode(Key.T.self, from: data)
            self.state[typeKey] = .hasGist(gist)
            return gist

          } catch let error as CocoaError {
            if error.code == .fileReadNoSuchFile {
              self.state[typeKey] = .noGist
              return nil
            }

            throw error
          }
        }
      }

    } catch let error {
      VitalLogger.core.error("failed to load \(key.identifier): \(error)", source: "VitalGistStorage")
      return nil
    }
  }

  func set<Key: GistKey>(_ newValue: VitalJWTAuthRecordGist?, for key: Key.Type) throws {
    let typeKey = ObjectIdentifier(key)
    let url = Self.fileURL(forKey: key.identifier)

    try lock.withLock {
      if let newValue = newValue {
        let directoryUrl = Self.directoryURL
        if !FileManager.default.fileExists(atPath: directoryUrl.path) {
          try FileManager.default.createDirectory(at: Self.directoryURL, withIntermediateDirectories: true)
        }

        let data = try JSONEncoder().encode(newValue)
        // noFileProtection to ensure that the gist is accessible even before first unlock.
        try data.write(to: url, options: [.atomic, .noFileProtection])
        self.state[typeKey] = .hasGist(newValue)

      } else {
        if FileManager.default.fileExists(atPath: url.path) {
          try FileManager.default.removeItem(at: url)
        }
        self.state[typeKey] = .noGist
      }
    }
  }

  enum State {
    case hasGist(Any)
    case noGist
    case uninitialized
  }
}
