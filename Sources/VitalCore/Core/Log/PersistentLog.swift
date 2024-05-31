import Foundation
import OSLog
import Dispatch
import Darwin


public final class VitalPersistentLogger: @unchecked Sendable {

  internal static let timeFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter
  }()

  @_spi(VitalSDKInternals)
  public static var shared: VitalPersistentLogger? {
    guard let result = _lock.withLock({ Self.checkEnabled() }) else { return nil }

    if result.created {
      VitalLogger.core.info("[PersistentLog] state: enabled (on first access by persistent settings)")
    }

    return result.logger
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
  /// - warning: This is not designed to be always-on logging. It should not be enabled in production except
  /// for troubleshooting purposes.
  public static var isEnabled: Bool {
    get { UserDefaults.standard.bool(forKey: Self.userDefaultsKey) }
    set {
      _lock.withLock {
        UserDefaults.standard.set(newValue, forKey: Self.userDefaultsKey)
        checkEnabled()
      }

      VitalLogger.core.info("[PersistentLog] state: \(newValue ? "enabled" : "disabled")")
    }
  }

  @discardableResult
  private static func checkEnabled() -> (logger: VitalPersistentLogger, created: Bool)? {
    switch (isEnabled, _shared) {
    case (false, nil):
      return nil

    case (false, .some):
      _shared = nil
      return nil

    case (true, nil):
      let persistentLogger = VitalPersistentLogger()
      _shared = persistentLogger
      return (persistentLogger, true)

    case let (true, logger?):
      return (logger, false)
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

  func log<T>(_ request: Request<T>) {
    self.logSync(.requestBody) { writeString, writeData in
      writeString(Self.timeFormatter.string(from: Date()))
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

  func logSync(_ category: VitalLogger.Category, _ message: @escaping ((String) -> Void, (Data) -> Void) throws -> Void) {
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
