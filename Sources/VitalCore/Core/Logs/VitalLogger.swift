import OSLog

public enum VitalLogger {
  public static let subsystem = "io.tryvital.vital-ios"

  public static let core = Logger(subsystem: Self.subsystem, category: "core")
  public static let healthKit = Logger(subsystem: Self.subsystem, category: "healthKit")
}
