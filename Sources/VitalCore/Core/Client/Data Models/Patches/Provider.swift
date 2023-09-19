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

  public enum Slug: Hashable, Codable, RawRepresentable {
    case beurerBLE
    case beurer
    case omronBLE
    case oneTouchBLE
    case accuchekBLE
    case contourBLE
    case appleHealthKit
    case manual
    case iHealth
    case libreBLE
    case libre
    case oura
    case garmin
    case fitbit
    case whoop
    case strava
    case renpho
    case peloton
    case wahoo
    case zwift
    case eightSleep
    case withings
    case googleFit
    case hammerhead
    case dexcom
    case myFitnessPal
    case healthConnect
    case unknown(String)

    public var rawValue: String {
      switch self {
      case .beurerBLE: return "beurer_ble"
      case .beurer: return "beurer_api"
      case .omronBLE: return "omron_ble"
      case .oneTouchBLE: return "onetouch_ble"
      case .accuchekBLE: return "accuchek_ble"
      case .contourBLE: return "contour_ble"
      case .appleHealthKit: return "apple_health_kit"
      case .manual: return "manual"
      case .iHealth: return "ihealth"
      case .libreBLE: return "freestyle_libre_ble"
      case .libre: return "freestyle_libre"
      case .oura: return "oura"
      case .garmin: return "garmin"
      case .fitbit: return "fitbit"
      case .whoop: return "whoop"
      case .strava: return "strava"
      case .renpho: return "renpho"
      case .peloton: return "peloton"
      case .wahoo: return "wahoo"
      case .zwift: return "zwift"
      case .eightSleep: return "eight_sleep"
      case .withings: return "withings"
      case .googleFit: return "google_fit"
      case .hammerhead: return "hammerhead"
      case .dexcom: return "dexcom"
      case .myFitnessPal: return "my_fitness_pal"
      case .healthConnect: return "health_connect"
      case let .unknown(rawValue): return rawValue
      }
    }

    public init?(rawValue: String) {
      switch rawValue {
      case "beurer_ble": self = .beurerBLE
      case "beurer_api": self = .beurer
      case "omron_ble": self = .omronBLE
      case "onetouch_ble": self = .oneTouchBLE
      case "accuchek_ble": self = .accuchekBLE
      case "contour_ble": self = .contourBLE
      case "apple_health_kit": self = .appleHealthKit
      case "manual": self = .manual
      case "ihealth": self = .iHealth
      case "freestyle_libre_ble": self = .libreBLE
      case "freestyle_libre": self = .libre
      case "oura": self = .oura
      case "garmin": self = .garmin
      case "fitbit": self = .fitbit
      case "whoop": self = .whoop
      case "strava": self = .strava
      case "renpho": self = .renpho
      case "peloton": self = .peloton
      case "wahoo": self = .wahoo
      case "zwift": self = .zwift
      case "eight_sleep": self = .eightSleep
      case "withings": self = .withings
      case "google_fit": self = .googleFit
      case "hammerhead": self = .hammerhead
      case "dexcom": self = .dexcom
      case "my_fitness_pal": self = .myFitnessPal
      case "health_connect": self = .healthConnect
      default: self = .unknown(rawValue)
      }
    }
  }
}
