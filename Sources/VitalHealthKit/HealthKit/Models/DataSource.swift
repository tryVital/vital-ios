public enum AppAllowlist: Codable {
  case all
  case specific([AppIdentifier])
}

public struct AppIdentifier: RawRepresentable, Codable {
  public let rawValue: String

  public init(rawValue: String) {
    self.rawValue = rawValue
  }

  public static let appleHealthKit = AppIdentifier(rawValue: "com.apple.health")
  public static let oura = AppIdentifier(rawValue: "com.ouraring.oura")
  public static let withings = AppIdentifier(rawValue: "com.withings.wiScaleNG")
  public static let whoop = AppIdentifier(rawValue: "com.whoop.iphone")
  public static let garmin = AppIdentifier(rawValue: "com.garmin.connect.mobile")
  public static let fitbit = AppIdentifier(rawValue: "com.fitbit.FitbitMobile")
  public static let polar = AppIdentifier(rawValue: "fi.polar.polarflow")
  public static let coros = AppIdentifier(rawValue: "com.coros.coros")
  public static let suunto = AppIdentifier(rawValue: "com.sports-tracker.suunto.iphone")
  public static let xiaomi = AppIdentifier(rawValue: "com.xiaomi.miwatch.pro")
  public static let muse = AppIdentifier(rawValue: "com.interaxon.muse")
  public static let biostrap = AppIdentifier(rawValue: "com.biostrap.Biostrap")
  public static let cardiomood = AppIdentifier(rawValue: "com.corsanohealth.cardiomood")
  public static let eightsleep = AppIdentifier(rawValue: "com.eightsleep.Eight")

  public static let defaultsleepDataAllowlist = [
    AppIdentifier.appleHealthKit, AppIdentifier.oura, AppIdentifier.withings,
    AppIdentifier.whoop, AppIdentifier.garmin, AppIdentifier.fitbit, AppIdentifier.polar,
    AppIdentifier.coros, AppIdentifier.suunto, AppIdentifier.xiaomi, AppIdentifier.muse,
    AppIdentifier.biostrap, AppIdentifier.cardiomood, AppIdentifier.eightsleep,
  ]
}
