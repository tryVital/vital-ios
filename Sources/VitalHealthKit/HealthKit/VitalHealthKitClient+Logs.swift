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

  public static func clearLogs() throws {
    guard let rootDirectoryURL = VitalPersistentLogger.shared?.directoryURL(for: nil) else { return }
    if FileManager.default.fileExists(atPath: rootDirectoryURL.absoluteString) {
      try FileManager.default.removeItem(at: rootDirectoryURL)
    }
  }

  @available(iOS 15.0, *)
  @discardableResult
  public static func logStateSnapshot() async throws -> URL {
    guard let logger = VitalPersistentLogger.shared else {
      throw LogArchivalError("VitalPersistentLogger is not enabled.")
    }

    let userId = VitalClient.currentUserId
    let sdkStatus = VitalClient.status
    let vitalCoreConfiguration = VitalClient.shared.configuration.value
    let vitalHealthKitConfiguration = shared.configuration.value

    let rootDirectoryURL = logger.directoryURL(for: nil)
    let logURL = rootDirectoryURL.appendingPathComponent("sdk-state-\(Int(Date.now.timeIntervalSince1970)).json")

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

    var data: [String: Any?] = await [
      "Device": [
        "OSVersion": UIDevice.current.systemVersion,
        "DeviceModel": UIDevice.current.model,
      ] as [String: Any?],
      "Core": [
        "Env": (vitalCoreConfiguration?.environment).map(String.init(describing:)) ?? "nil",
        "AuthMode": vitalCoreConfiguration?.authMode.rawValue ?? "nil",
        "CurrentUserId": userId,
        "CurrentSDKStatus": String(describing: sdkStatus),
      ] as [String: Any?],
      "Health": [
        "Config": vitalHealthKitConfiguration.map(String.init(describing:)) ?? "nil",
        "PauseSynchronization": VitalHealthKitClient.shared.pauseSynchronization,
      ],
    ]

    let healthStore = HKHealthStore()

    let permissionState = try await withThrowingTaskGroup(of: (VitalResource, [String: [String]]).self) { group in
      for resource in VitalResource.all {
        group.addTask {
          let requirements = toHealthKitTypes(resource: resource)
          let allHealthKitTypes = requirements.allObjectTypes

          return try await withThrowingTaskGroup(of: (HKObjectType, HKAuthorizationRequestStatus, HKAuthorizationStatus).self) { innerGroup in
            for objectType in allHealthKitTypes {
              innerGroup.addTask {
                let requestStatus = try await healthStore.statusForAuthorizationRequest(toShare: [], read: [objectType])
                let canShare = healthStore.authorizationStatus(for: objectType)
                return (objectType, requestStatus, canShare)
              }
            }

            let output = try await innerGroup.reduce(into: [String: [String]]()) { output, result in
              let (objectType, readRequestStatus, shareRequestStatus) = result
              var remarks = [String]()

              switch readRequestStatus {
              case .shouldRequest:
                remarks.append("read:willPrompt")
              case .unnecessary:
                remarks.append("read:asked")
              case .unknown:
                fallthrough
              @unknown default:
                remarks.append("read:unknown")
              }

              switch shareRequestStatus {
              case .sharingAuthorized:
                remarks.append("write:granted")
              case .sharingDenied:
                remarks.append("write:denied")
              case .notDetermined:
                fallthrough
              @unknown default:
                remarks.append("write:unknown")
              }

              output[objectType.identifier] = remarks
            }

            return (resource, output)
          }
        }
      }

      return try await group.reduce(into: [String: [String: [String]]]()) { output, result in
        let (resource, innerOutput) = result
        output[resource.logDescription] = innerOutput
      }
    }

    data["permissions"] = permissionState

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

    data["storage"] = storageDump

    let dataJson = try JSONSerialization.data(withJSONObject: data, options: [.prettyPrinted, .sortedKeys])
    write(String(data: dataJson, encoding: .utf8) ?? "")

    return logURL
  }
}
