import Foundation
import UIKit
import HealthKit
@_spi(VitalSDKInternals) import VitalCore
import AppleArchive
import System

extension VitalHealthKitClient {
  public struct LogArchivalError: Error, CustomStringConvertible {
    public let description: String

    public init(_ description: String) {
      self.description = description
    }
  }

  @available(iOS 15.0, *)
  public static func createAndShareLogArchive() {
    let archiveUrlTask = Task { try await Self.createLogArchive() }

    Task { @MainActor in
      let result = await archiveUrlTask.result

      var topViewController = UIApplication.shared.connectedScenes
        .compactMap { $0 as? UIWindowScene }
        .first { $0.session.role == .windowApplication }?
        .keyWindow?
        .rootViewController

      while let modal = topViewController?.presentedViewController {
        topViewController = modal
      }

      switch result {
      case let .success(archiveUrl):
        topViewController?.present(
          UIActivityViewController(activityItems: [archiveUrl], applicationActivities: nil),
          animated: true
        )

      case let .failure(error):
        let alertController = UIAlertController(
          title: "Failed to create archive",
          message: String(describing: error),
          preferredStyle: .alert
        )
        alertController.addAction(UIAlertAction(title: "OK", style: .default))
        topViewController?.present(alertController, animated: true)
      }
    }
  }

  @available(iOS 15.0, *)
  public static func createLogArchive() async throws -> URL {
    guard let logger = VitalPersistentLogger.shared else {
      throw LogArchivalError("VitalPersistentLogger is not enabled.")
    }

    try await logStateSnapshot()

    let rootDirectoryURL = logger.directoryURL(for: nil)
    let archiveUrl = FileManager.default.temporaryDirectory
      .appendingPathComponent("vital-\(Int(Date.now.timeIntervalSince1970)).aar")
    guard let archiveFilePath = FilePath(archiveUrl), let rootDirectoryPath = FilePath(rootDirectoryURL) else {
      throw LogArchivalError("Failed to create FilePath for archive.")
    }

    do {
      try ArchiveByteStream.withFileStream(
        path: archiveFilePath,
        mode: .writeOnly,
        options: [.create],
        permissions: FilePermissions(rawValue: 0o644)
      ) { fileStream in
        try ArchiveByteStream.withCompressionStream(
          using: .lzfse,
          writingTo: fileStream
        ) { compressionStream in
          try ArchiveStream.withEncodeStream(writingTo: compressionStream) { encodeStream in
            try encodeStream.writeDirectoryContents(
              archiveFrom: rootDirectoryPath,
              keySet: .defaultForArchive
            )
          }
        }
      }
    } catch let error {
      throw LogArchivalError("Failed to create archive at \(archiveUrl.path): \(error)")
    }

    return archiveUrl
  }

  @available(iOS 15.0, *)
  @discardableResult
  public static func logStateSnapshot() async throws -> URL {
    guard let logger = VitalPersistentLogger.shared else {
      throw LogArchivalError("VitalPersistentLogger is not enabled.")
    }

    let userId = VitalClient.currentUserId
    let vitalCoreConfiguration = VitalClient.shared.configuration.value
    let vitalHealthKitConfiguration = shared.configuration.value

    let rootDirectoryURL = logger.directoryURL(for: nil)
    let logURL = rootDirectoryURL.appendingPathComponent("vitalhealthkit-state-\(Int(Date.now.timeIntervalSince1970)).log")

    try FileManager.default.createDirectory(at: rootDirectoryURL, withIntermediateDirectories: true)

    let stream = OutputStream(url: logURL, append: false)!
    stream.open()
    defer { stream.close() }

    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]

    func write(_ string: String) {
      var string = string + "\r\n"
      string.withUTF8 { buffer in
        let bytesWritten = stream.write(buffer.baseAddress!, maxLength: buffer.count)
        precondition(bytesWritten > 0)
      }
    }

    let environmentMessage = await Task { @MainActor in
      """
      OS_VERSION: \(UIDevice.current.systemVersion)
      DEVICE_MODEL: \(UIDevice.current.model)
      """
    }.value

    write("""
    \(environmentMessage)
    VITAL_ENV: \((vitalCoreConfiguration?.environment).map(String.init(describing:)) ?? "nil")
    VITAL_API_VERSION: \(vitalCoreConfiguration?.apiVersion ?? "nil")
    VITAL_AUTH_MODE: \(vitalCoreConfiguration?.authMode.rawValue ?? "nil")
    USER_ID: \(userId ?? "nil")
    VITAL_HK_CONFIG: \(vitalHealthKitConfiguration.map(String.init(describing:)) ?? "nil")
    """)

    write(">>> HKHEALTHSTORE")
    let healthStore = HKHealthStore()

    for objectType in VitalResource.all.flatMap(toHealthKitTypes) {
      let requestStatus = try await healthStore.statusForAuthorizationRequest(toShare: [], read: [objectType])
      let authorizationStatus = healthStore.authorizationStatus(for: objectType)
      let remarks = (requestStatus == .unnecessary && authorizationStatus == .sharingDenied) ? "(readonly granted?)" : ""
      write("\(objectType.identifier) = \(requestStatus.name),\(authorizationStatus.name) \(remarks)")
    }

    write(">>> VITALHEALTHKIT_STORAGE")

    let storageDump = shared.storage.dump().mapValues { value -> Any? in
      switch value {
      case let value as NSDate:
        return formatter.string(from: value as Date)
      case let data as NSData:
        let data = data as Data

        // First try HKQueryAnchor
        if let anchor = try? NSKeyedUnarchiver.unarchivedObject(ofClass: HKQueryAnchor.self, from: data) {
          return "\(anchor)"
        }

        // Then try JSON
        return String(data: data, encoding: .utf8) ?? "<NSData with unknown encoding>"
      default:
        return value
      }
    }
    let storageJson = try JSONSerialization.data(withJSONObject: storageDump, options: [.prettyPrinted, .sortedKeys])
    write(String(data: storageJson, encoding: .utf8) ?? "")

    return logURL
  }
}


extension HKAuthorizationStatus {
  fileprivate var name: String {
    switch self {
    case .notDetermined:
      return "not_determined"
    case .sharingAuthorized:
      return "sharing_authorized"
    case .sharingDenied:
      return "sharing_denied"
    @unknown default:
      return "UNKNOWN"
    }
  }
}


extension HKAuthorizationRequestStatus {
  fileprivate var name: String {
    switch self {
    case .shouldRequest:
      return "should_request"
    case .unknown:
      return "unknown"
    case .unnecessary:
      return "unnecessary"
    @unknown default:
      return "UNKNOWN"
    }
  }
}
