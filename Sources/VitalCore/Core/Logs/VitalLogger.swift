import Logging
import Foundation

public enum VitalLogger {
  public static let subsystem = "io.tryvital.vital-ios"

  public static let core = Logging.Logger(label: Category.core.rawValue, factory: Self.logHandlerFactory)
  public static let requests = Logging.Logger(label: Category.requests.rawValue, factory: Self.logHandlerFactory)
  public static let healthKit = Logging.Logger(label: Category.healthKit.rawValue, factory: Self.logHandlerFactory)

  public enum Category: String {
    case core
    case requests
    case healthKit
    case requestBody
  }

  private static func logHandlerFactory(label: String) -> Logging.LogHandler {
    MultiplexLogHandler([
      StreamLogHandler.standardOutput(label: label),
      VitalPersistentLoggerWrapper(label: label),
    ])
  }
}


private struct VitalPersistentLoggerWrapper: Logging.LogHandler {

  var category: VitalLogger.Category

  var metadata = Logging.Logger.Metadata()
  var logLevel: Logging.Logger.Level = .info

  init(label: String) {
    self.category = VitalLogger.Category(rawValue: label)!
  }

  subscript(metadataKey metadataKey: String) -> Logging.Logger.Metadata.Value? {
      get { return self.metadata[metadataKey] }
      set { self.metadata[metadataKey] = newValue }
  }

  func log(
    level: Logging.Logger.Level,
    message: Logging.Logger.Message,
    metadata: Logging.Logger.Metadata?,
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
