import VitalLogging
import Foundation
import os

public enum VitalLogger {
  public static let subsystem = "io.tryvital.vital-ios"

  /// Whether logs should be written to stdout, when the library is built with Debug configuration.
  /// This is `false` (disabled) by default.
  ///
  /// - important: Logging to stdout is always disabled when the library is built with Release configuration.
  ///              Use `VitalPersistentLogger` if you need to gather logs in Release builds.
  public static var stdOutEnabled: Bool {
    get { logLevelRequest.stdOut < .error }
    set { logLevelRequest.stdOut = newValue ? .info : .error }
  }

  @preconcurrency
  internal static var logLevelRequest: (
    persistentLogger: VitalLogging.Logger.Level,
    stdOut: VitalLogging.Logger.Level
  ) = {
    return (
      persistentLogger: VitalPersistentLogger.isEnabled ? .info : .error,
      stdOut: .error
    )
  }() {

    didSet {
      let newValue = min(logLevelRequest.persistentLogger, logLevelRequest.stdOut)
      core.logLevel = newValue
      requests.logLevel = newValue
      healthKit.logLevel = newValue
    }
  }

  public private(set) static var core = VitalLogging.Logger(label: Category.core.rawValue, factory: Self.logHandlerFactory)
  public private(set) static var devices = VitalLogging.Logger(label: Category.devices.rawValue, factory: Self.logHandlerFactory)
  public private(set) static var requests = VitalLogging.Logger(label: Category.requests.rawValue, factory: Self.logHandlerFactory)
  public private(set) static var healthKit = VitalLogging.Logger(label: Category.healthKit.rawValue, factory: Self.logHandlerFactory)

  public enum Category: String {
    case core
    case requests
    case healthKit
    case devices
    case requestBody
  }

  private static func logHandlerFactory(label: String) -> VitalLogging.LogHandler {
    var handlers = [VitalLogging.LogHandler]()

    #if DEBUG
    handlers.append(StreamLogHandler.standardOutput(label: label))
    #endif

    handlers.append(VitalPersistentLoggerWrapper(label: label))

    var handler = MultiplexLogHandler(handlers)
    handler.logLevel = min(logLevelRequest.persistentLogger, logLevelRequest.stdOut)

    return handler
  }
}


private struct VitalStreamLogHandlerWrapper: VitalLogging.LogHandler {
  var metadata: VitalLogging.Logger.Metadata {
    get { wrapped.metadata }
    set { wrapped.metadata = newValue }
  }

  var logLevel: VitalLogging.Logger.Level {
    get { wrapped.logLevel }
    set { wrapped.logLevel = newValue }
  }

  var wrapped: StreamLogHandler

  init(wrapped: StreamLogHandler) {
    self.wrapped = wrapped
  }

  subscript(metadataKey metadataKey: String) -> VitalLogging.Logger.Metadata.Value? {
    get { return self.wrapped[metadataKey: metadataKey] }
    set { self.wrapped[metadataKey: metadataKey] = newValue }
  }

  func log(level: VitalLogging.Logger.Level, message: VitalLogging.Logger.Message, metadata: VitalLogging.Logger.Metadata?, source: String, file: String, function: String, line: UInt) {
    guard VitalLogger.logLevelRequest.stdOut <= level else { return }
    wrapped.log(level: level, message: message, metadata: metadata, source: source, file: file, function: function, line: line)
  }
}

private struct VitalPersistentLoggerWrapper: VitalLogging.LogHandler {

  var category: VitalLogger.Category

  var metadata = VitalLogging.Logger.Metadata()
  var logLevel: VitalLogging.Logger.Level = .info

  init(label: String) {
    self.category = VitalLogger.Category(rawValue: label)!
  }

  subscript(metadataKey metadataKey: String) -> VitalLogging.Logger.Metadata.Value? {
      get { return self.metadata[metadataKey] }
      set { self.metadata[metadataKey] = newValue }
  }

  func log(
    level: VitalLogging.Logger.Level,
    message: VitalLogging.Logger.Message,
    metadata: VitalLogging.Logger.Metadata?,
    source: String,
    file: String,
    function: String,
    line: UInt
  ) {
    guard let logger = VitalPersistentLogger.shared else { return }

    logger.logSync(self.category) { writeString, writeData in
      let timeformatter = VitalPersistentLogger.timeFormatter
      writeString("\(timeformatter.string(from: Date())) \(level) : \(message)")
    }
  }
}
