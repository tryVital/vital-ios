import VitalLogging
import Foundation

public enum VitalLogger {
  public static let subsystem = "io.tryvital.vital-ios"

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
    MultiplexLogHandler([
      StreamLogHandler.standardOutput(label: label),
      VitalPersistentLoggerWrapper(label: label),
    ])
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
