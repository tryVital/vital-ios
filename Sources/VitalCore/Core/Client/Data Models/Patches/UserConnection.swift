struct ProviderResponse: Equatable, Decodable {
  struct Provider: Equatable, Decodable {
    let name: String
    let slug: VitalCore.Provider.Slug
    let logo: String
    let status: VitalCore.UserConnection.Status
    let resourceAvailability: [VitalAPIResource: VitalCore.UserConnection.ResourceAvailability]

    enum CodingKeys: CodingKey {
      case name
      case slug
      case logo
      case status
      case resourceAvailability
    }

    init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: ProviderResponse.Provider.CodingKeys.self)
      self.name = try container.decode(
        String.self,
        forKey: ProviderResponse.Provider.CodingKeys.name
      )
      self.slug = try container.decode(
        VitalCore.Provider.Slug.self,
        forKey: ProviderResponse.Provider.CodingKeys.slug
      )
      self.logo = try container.decode(
        String.self,
        forKey: ProviderResponse.Provider.CodingKeys.logo
      )
      self.status = try container.decode(
        VitalCore.UserConnection.Status.self,
        forKey: ProviderResponse.Provider.CodingKeys.status
      )
      let resourceAvailability = try container.decode(
        [String : VitalCore.UserConnection.ResourceAvailability].self,
        forKey: ProviderResponse.Provider.CodingKeys.resourceAvailability
      )
      self.resourceAvailability = Dictionary(
        uniqueKeysWithValues: resourceAvailability.map { key, value in
          (VitalAPIResource(rawValue: key), value)
        }
      )
    }
  }
  
  let providers: [ProviderResponse.Provider]
}

public struct UserConnection: Equatable {
  public let name: String
  public let slug: Provider.Slug
  public let logo: String
  public let status: Status
  public let resourceAvailability: [VitalAPIResource: VitalCore.UserConnection.ResourceAvailability]

  public enum Status: String, Codable, RawRepresentable {
    case connected
    case error
    case paused
    case unrecognized

    public init(from decoder: Decoder) throws {
      let container = try decoder.singleValueContainer()
      switch try container.decode(String.self) {
      case "connected":
        self = .connected
      case "error":
        self = .error
      case "paused":
        self = .paused
      default:
        self = .unrecognized
      }
    }
  }

  public struct ResourceAvailability: Equatable, Decodable {
    public let status: Status
    public let scopeRequirements: ScopeRequirementsGrants?

    public init(status: Status, scopeRequirements: ScopeRequirementsGrants?) {
      self.status = status
      self.scopeRequirements = scopeRequirements
    }

    public enum Status: String, Decodable, RawRepresentable {
      case available
      case unavailable
    }
  }

  public struct ScopeRequirementsGrants: Equatable, Decodable {
    public let userGranted: ScopeRequirements
    public let userDenied: ScopeRequirements

    public init(userGranted: ScopeRequirements, userDenied: ScopeRequirements) {
      self.userGranted = userGranted
      self.userDenied = userDenied
    }
  }

  public struct ScopeRequirements: Equatable, Decodable {
    public let required: [String]
    public let optional: [String]

    public init(required: [String], optional: [String]) {
      self.required = required
      self.optional = optional
    }
  }
}

public struct Provider: Equatable {
  public let name: String
  public let slug: Slug
  public let logo: String

  public enum Slug: Hashable, Codable, RawRepresentable {
    case beurerBLE
    case beurer
    case omron
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
    case whoopV2
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
    case dexcomV3
    case myFitnessPal
    case healthConnect
    case kardia
    case cronometer
    case polar
    case unknown(String)

    public var rawValue: String {
      switch self {
      case .beurerBLE: return "beurer_ble"
      case .beurer: return "beurer_api"
      case .omron: return "omron"
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
      case .whoopV2: return "whoop_v2"
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
      case .dexcomV3: return "dexcom_v3"
      case .myFitnessPal: return "my_fitness_pal"
      case .healthConnect: return "health_connect"
      case .kardia: return "kardia"
      case .cronometer: return "cronometer"
      case .polar: return "polar"
      case let .unknown(rawValue): return rawValue
      }
    }

    public init?(rawValue: String) {
      switch rawValue {
      case "beurer_ble": self = .beurerBLE
      case "beurer_api": self = .beurer
      case "omron": self = .omron
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
      case "whoop_v2": self = .whoopV2
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
      case "dexcom_v3": self = .dexcomV3
      case "my_fitness_pal": self = .myFitnessPal
      case "health_connect": self = .healthConnect
      case "kardia": self = .kardia
      case "cronometer": self = .cronometer
      case "polar": self = .polar
      default: self = .unknown(rawValue)
      }
    }
  }
}
