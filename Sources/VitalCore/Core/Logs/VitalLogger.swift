import OSLog

public enum VitalLogger {
  public static let subsystem = "io.tryvital.vital-ios"

  public static let core = Logger(subsystem: Self.subsystem, category: Category.core.rawValue)
  public static let requests = Logger(subsystem: Self.subsystem, category: Category.requests.rawValue)
  public static let healthKit = Logger(subsystem: Self.subsystem, category: Category.healthKit.rawValue)

  public enum Category: String {
    case core
    case requests
    case healthKit
    case requestBody
  }
}
