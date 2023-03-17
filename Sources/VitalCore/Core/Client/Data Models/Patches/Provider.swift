struct ProviderResponse: Equatable, Decodable {
  struct Provider: Equatable, Decodable {
    let name: String
    let slug: VitalCore.Provider.Slug
    let logo: String
  }
  
  let providers: [ProviderResponse.Provider]
}

public struct Provider: Equatable {
  public let name: String
  public let slug: Slug
  public let logo: String

  public struct Slug: Hashable, RawRepresentable, Codable, ExpressibleByStringLiteral {
    public static let beurerBLE: Self = "beurer_ble"
    public static let beurer: Self = "beurer_api"
    public static let omronBLE: Self = "omron_ble"
    public static let accuchekBLE: Self = "accuchek_ble"
    public static let contourBLE: Self = "contour_ble"
    public static let appleHealthKit: Self = "apple_health_kit"
    public static let manual: Self = "manual"
    public static let iHealth: Self = "ihealth"
    public static let libreBLE: Self = "freestyle_libre_ble"
    public static let libre: Self = "freestyle_libre"
    public static let oura: Self = "oura"
    public static let garmin: Self = "garmin"
    public static let fitbit: Self = "fitbit"
    public static let whoop: Self = "whoop"
    public static let strava: Self = "strava"
    public static let renpho: Self = "renpho"
    public static let peloton: Self = "peloton"
    public static let wahoo: Self = "wahoo"
    public static let zwift: Self = "zwift"
    public static let eightSleep: Self = "eight_sleep"
    public static let withings: Self = "withings"
    public static let googleFit: Self = "google_fit"
    public static let hammerhead: Self = "hammerhead"
    public static let dexcom: Self = "dexcom"
    public static let myFitnessPal: Self = "my_fitness_pal"
    public static let healthConnect: Self = "health_connect"

    public let rawValue: String

    public init(stringLiteral value: StringLiteralType) {
      self.init(rawValue: value)
    }

    public init(rawValue: String) {
      self.rawValue = rawValue
    }
  }
}
