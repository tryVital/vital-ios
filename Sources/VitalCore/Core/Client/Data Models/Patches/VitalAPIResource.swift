public struct VitalAPIResource: Hashable, Codable, RawRepresentable {
  public let rawValue: String

  public init(rawValue: String) {
    self.rawValue = rawValue
  }

  public static let activity = VitalAPIResource(rawValue: "activity")
  public static let sleep = VitalAPIResource(rawValue: "sleep")
  public static let workouts = VitalAPIResource(rawValue: "workouts")
  public static let body = VitalAPIResource(rawValue: "body")
}
