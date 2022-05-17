import CoreBluetooth
import VitalCore

public extension DevicesManager {
  static func devices(for brand: Brand) -> [DeviceModel] {
    return [
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
      )
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
      case "contour_next_one":
        return ["contour"]
      case "beurer":
        return ["Beuerer", "BC","bc"]
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
      case .libre:
        fatalError("No service for Libre")
    }
    
    return CBUUID(string: id.fullUUID)
  }
  
  static func brands() -> [Brand] {
    return [
      .omron,
      .accuChek,
      .contour,
      .beurer,
      .libre
    ]
  }
  
  static func provider(for brand: Brand) -> Provider {
    switch brand {
      case .omron:
        return .omron
      case .accuChek:
        return .accuchek
      case .contour:
        return .contour
      case .beurer:
        return .beurer
      case .libre:
        return .libre
    }
  }
}
