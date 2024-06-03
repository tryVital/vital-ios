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
    get { _stdOutEnabled }
    set { _stdOutEnabled = newValue }
  }

  @preconcurrency
  internal static var _stdOutEnabled: Bool = false

  public static let core = VitalLogging.Logger(label: Category.core.rawValue, factory: Self.logHandlerFactory)
  public static let requests = VitalLogging.Logger(label: Category.requests.rawValue, factory: Self.logHandlerFactory)
  public static let healthKit = VitalLogging.Logger(label: Category.healthKit.rawValue, factory: Self.logHandlerFactory)

  public enum Category: String {
    case core
    case requests
    case healthKit
    case requestBody
  }

  private static func logHandlerFactory(label: String) -> VitalLogging.LogHandler {
    var handlers = [VitalLogging.LogHandler]()

    #if DEBUG
    handlers.append(StreamLogHandler.standardOutput(label: label))
    #endif

    handlers.append(VitalPersistentLoggerWrapper(label: label))

    return MultiplexLogHandler(handlers)
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
    guard VitalLogger._stdOutEnabled else { return }
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
