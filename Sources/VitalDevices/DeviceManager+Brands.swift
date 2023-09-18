import CoreBluetooth
import VitalCore

public extension DevicesManager {
  /// Special string to detect the Vital BLE simulator entry.
  static let vitalBLESimulator = "$vital_ble_simulator$"

  static func devices(for brand: Brand) -> [DeviceModel] {
    return [
      .init(
        id: "onetouch_verio_reflect",
        name: "OneTouch Verio Reflect",
        brand: .oneTouch,
        kind: .glucoseMeter
      ),
      .init(
        id: "omron_m4",
        name: "Omron Intelli IT M4",
        brand: .omron,
        kind: .bloodPressure
      ),
      .init(
        id: "omron_m7",
        name: "Omron Intelli IT M7",
        brand: .omron,
        kind: .bloodPressure
      ),
      .init(
        id: "accuchek_guide",
        name: "Accu-Chek Guide",
        brand: .accuChek,
        kind: .glucoseMeter
      ),
      .init(
        id: "accuchek_guide_me",
        name: "Accu-Chek Guide Me",
        brand: .accuChek,
        kind: .glucoseMeter
      ),
      .init(
        id: "accuchek_guide_active",
        name: "Accu-Chek Active",
        brand: .accuChek,
        kind: .glucoseMeter
      ),
      .init(
        id: "contour_next_one",
        name: "Contour Next One",
        brand: .contour,
        kind: .glucoseMeter
      ),
      .init(
        id: "beurer",
        name: "Beurer Devices",
        brand: .beurer,
        kind: .bloodPressure
      ),
      .init(
        id: "libre1",
        name: "Freestyle Libre 1",
        brand: .libre,
        kind: .glucoseMeter
      ),
      .init(
        id: Self.vitalBLESimulator,
        name: "Vital BLE Simulator",
        brand: .accuChek,
        kind: .glucoseMeter
      ),
    ].filter {
      $0.brand == brand
    }
  }
  
  static func codes(for deviceId: String) -> [String] {
    switch deviceId {
      case "omron_m4":
        return ["OMRON", "M4","X4", "BLESMART"]
      case "omron_m7":
        return ["OMRON", "M7", "BLESMART"]
      case "accuchek_guide":
        return ["meter"]
      case "accuchek_guide_me":
        return ["meter"]
      case "accuchek_guide_active":
        return ["meter"]
      case Self.vitalBLESimulator:
        return [Self.vitalBLESimulator]
      case "contour_next_one":
        return ["contour"]
      case "beurer":
        return ["Beuerer", "BC","bc"]
      case "onetouch_verio_reflect":
        return ["OneTouch"]
      default:
        return []
    }
  }

  static func service(for brand: Brand) -> CBUUID {
    let id: String

    switch brand {
      case .omron, .beurer:
        id = "1810"
      case .accuChek, .contour:
        id = "1808"
      case .oneTouch:
        return VerioGlucoseMeter.serviceID
      case .libre:
        fatalError("No GATT service for \(brand)")
    }

    return CBUUID(string: id.fullUUID)
  }

  static func advertisementService(for brand: Brand) -> CBUUID? {
    let id: String

    switch brand {
      case .omron, .beurer:
        id = "1810"
      case .accuChek, .contour:
        id = "1808"
      case .oneTouch:
        return nil
      case .libre:
        fatalError("No GATT service for \(brand)")
    }

    return CBUUID(string: id.fullUUID)
  }
  
  static func brands() -> [Brand] {
    return [
      .oneTouch,
      .omron,
      .accuChek,
      .contour,
      .beurer,
      .libre,
    ]
  }
  
  static func provider(for brand: Brand) -> Provider.Slug {
    switch brand {
      case .omron:
        return .omronBLE
      case .accuChek:
        return .accuchekBLE
      case .contour:
        return .contourBLE
      case .beurer:
        return .beurer
      case .libre:
        return .libre
    case .oneTouch:
      return .oneTouchBLE
    }
  }
}
