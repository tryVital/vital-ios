struct ProviderResponse: Equatable, Decodable {
  struct Provider: Equatable, Decodable {
    let name: String
    let slug: String
    let logo: String
  }
  
  let providers: [ProviderResponse.Provider]
}

public enum Provider: String, Codable {
  case beurerBLE = "beurer_ble"
  case beurer = "beurer_api"
  case omronBLE = "omron_ble"
  case accuchekBLE = "accuchek_ble"
  case contourBLE = "contour_ble"
  case appleHealthKit = "apple_health_kit"
  case manual = "manual"
  case iHealth = "ihealth"
  case libreBLE = "freestyle_libre_ble"
  case libre = "freestyle_libre"
  case oura = "oura"
  case garmin = "garmin"
  case fitbit = "fitbit"
  case whoop = "whoop"
  case strava = "strava"
  case renpho = "renpho"
  case peloton = "peloton"
  case wahoo = "wahoo"
  case zwift = "zwift"
  case eightSleep = "eight_sleep"
  case withings = "withings"
  case googleFit = "google_fit"
}
