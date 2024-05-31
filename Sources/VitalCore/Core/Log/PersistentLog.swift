import Foundation
import OSLog
import Dispatch
import Darwin


public final class VitalPersistentLogger: @unchecked Sendable {
  private let requestLogQueue = DispatchQueue(label: "io.tryvital.PersistentLogger.requests", target: .global(qos: .userInitiated))
  private let osLogDumpQueue = DispatchQueue(label: "io.tryvital.PersistentLogger.osLog", target: .global(qos: .userInitiated))
  private var lastDump: [VitalLogger.Category: Date] = [:]

  @_spi(VitalSDKInternals)
  public static var shared: VitalPersistentLogger? {
    _lock.withLock {
      if let logger = Self._shared {
        return logger
      } else {
        return Self.checkEnabled(context: "defaults on first access")
      }
    }
  }

  private static let _lock = NSLock()
  private static var _shared: VitalPersistentLogger? = nil
  private static let userDefaultsKey = "io.tryvital.VitalPersistentLogger.enabled"

  /// Enable persistent logging in Vital SDK. The enablement is persistent across app launches.
  ///
  /// When enabled, Vital dumps state snapshots, log messages and network request bodies from itself to the system-desginated
  /// temporary directory in persistent storage. Note that they may be eligible to be purged by the OS when the
  /// persistent storage is under pressure.
  ///
  /// You can retrieve the logs by either:
  /// * `VitalHealthKitClient.Type.createLogArchive()` in the form of a file URL; or
  /// * `VitalHealthKitClient.Type.createAndShareLogArchive()` where the system share sheet is prompted with the log archive.
  ///
  /// - warning: Avoid enabling this by default, especially in production.
  public static var isEnabled: Bool {
    get { UserDefaults.standard.bool(forKey: Self.userDefaultsKey) }
    set {
      _lock.withLock {
        UserDefaults.standard.set(newValue, forKey: Self.userDefaultsKey)
        checkEnabled(context: "explicit enablement")
      }
    }
  }

  @discardableResult
  private static func checkEnabled(context: StaticString) -> VitalPersistentLogger? {
    switch (isEnabled, _shared) {
    case (false, nil):
      return nil

    case (false, .some):
      _shared = nil

      VitalLogger.core.info("[PersistentLogger] disabled")
      return nil

    case (true, nil):
      let persistentLogger = VitalPersistentLogger()
      _shared = persistentLogger

      VitalLogger.core.info("[PersistentLogger] enabled via \(context, privacy: .public)")
      return persistentLogger

    case let (true, logger?):
      return logger
    }
  }

  public init() {}

  @_spi(VitalSDKInternals)
  public func directoryURL(for category: VitalLogger.Category?) -> URL {
    let url = URL(fileURLWithPath: NSTemporaryDirectory())
    var directoryUrl = url.appendingPathComponent("vital", isDirectory: true)

    if let category = category {
      directoryUrl = directoryUrl.appendingPathComponent(category.rawValue, isDirectory: true)
    }

    return directoryUrl
  }

  @_spi(VitalSDKInternals)
  public func dayURL(for category: VitalLogger.Category) -> URL {
    let directoryUrl = directoryURL(for: category)
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withFullDate, .withDashSeparatorInDate]
    let calendarDate = formatter.string(from: Date())

    let fileUrl = directoryUrl.appendingPathComponent("\(calendarDate).log")

    let exists = FileManager.default.fileExists(atPath: fileUrl.absoluteString)

    if !exists {
      try! FileManager.default.createDirectory(at: directoryUrl, withIntermediateDirectories: true)
      FileManager.default.createFile(atPath: fileUrl.absoluteString, contents: Data())
    }

    return fileUrl
  }

  @_spi(VitalSDKInternals)
  public func dumpOSLog(_ category: VitalLogger.Category) {
    if #available(iOS 15.0, *) {
      osLogDumpQueue.async {
        do {
          let store = try OSLogStore(scope: .currentProcessIdentifier)

          var lastDump = self.lastDump[category, default: .distantPast]
          let position = store.position(date: lastDump)

          let predicate = NSPredicate(format: "subsystem = %@ AND category = %@", VitalLogger.subsystem, category.rawValue)
          let entries = try store.getEntries(at: position, matching: predicate)

          let formatter = ISO8601DateFormatter()
          formatter.formatOptions = [.withInternetDateTime]

          self._log(category) { writeString, _ in
            for entry in entries {
              let level = (entry as? OSLogEntryLog)?.level ?? .undefined
              writeString("\(level.name) \(formatter.string(from: entry.date)) \(entry.composedMessage)")

              lastDump = entry.date
            }
          }

          self.lastDump[category] = lastDump
        } catch let error {
          self._log(category) { writeString, _ in
            writeString("<OSLogDump failure: \(error)>")
          }
        }
      }
    }
  }

  func log<T>(_ request: Request<T>) {
    requestLogQueue.async {
      self._log(.requestBody) { writeString, writeData in
        writeString("\(request.method.rawValue) \(request.url?.absoluteString ?? "UNKNOWN_URL")")

        if let body = request.body {
          let encoder = JSONEncoder()
          encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

          do {
            let data = try encoder.encode(body)
            writeString("uncompressed size: \(data.count) bytes")
            writeData(data)
          } catch let error {
            writeString("<encoder failure: \(error)>")
          }
        }

        // New line
        writeString("")
      }
    }
  }

  private func _log(_ category: VitalLogger.Category, _ message: @escaping ((String) -> Void, (Data) -> Void) throws -> Void) {
    do {
      let stream = OutputStream(url: dayURL(for: category), append: true)!
      stream.open()
      defer { stream.close() }

      func writeString(_ string: String) {
        var string = string + "\r\n"
        string.withUTF8 { buffer in
          let bytesWritten = stream.write(buffer.baseAddress!, maxLength: buffer.count)
          precondition(bytesWritten > 0)
        }
      }

      func writeData(_ bytes: Data) {
        bytes.withUnsafeBytes { buffer in
          let bytesWritten = stream.write(buffer.baseAddress!, maxLength: buffer.count)
          precondition(bytesWritten > 0)
        }

        // New line
        writeString("")
      }

      try message(writeString, writeData)
    } catch _ {

    }
  }
}

@available(iOS 15.0, *)
extension OSLogEntryLog.Level {
  fileprivate var name: String {
    switch self {
    case .undefined:
      return "UNDEFINED"
    case .debug:
      return "DEBUG"
    case .info:
      return "INFO"
    case .notice:
      return "NOTICE"
    case .error:
      return "ERROR"
    case .fault:
      return "FAULT"
    @unknown default:
      return "UNKNOWN"
    }
  }
}
