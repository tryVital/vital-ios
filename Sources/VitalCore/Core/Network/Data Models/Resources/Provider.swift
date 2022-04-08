public enum Provider: String, Encodable {
  case beurer = "beurer_ble"
  case omron = "omron_ble"
  case accuchek = "accuchek_ble"
  case contour = "contour_ble"
  case appleHealthKit = "apple_health_kit"
  case manual = "manual"
}
