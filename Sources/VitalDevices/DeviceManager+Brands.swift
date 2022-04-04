import CoreBluetooth
public extension DevicesManager {
  static func devices(for brand: Brand) -> [DeviceModel] {
        return [
          .init(
            id: "omron_m4",
            name: "Omron Intelli IT M4",
            brand: .omron,
            codes: ["OMRON", "M4", "BLESMART"],
            kind: .bloodPressure
          ),
          .init(
            id: "omron_m7",
            name: "Omron Intelli IT M7",
            brand: .omron,
            codes: ["OMRON", "M7", "BLESMART"],
            kind: .bloodPressure
          ),
          .init(
            id: "accuchek_guide",
            name: "Accu-Chek Guide",
            brand: .accuCheck,
            codes: ["meter"],
            kind: .glucoseMeter
          ),
          .init(
            id: "accuchek_guide_me",
            name: "Accu-Chek Guide Me",
            brand: .accuCheck,
            codes: ["meter"],
            kind: .glucoseMeter
          ),
          .init(
            id: "accuchek_guide_active",
            name: "Accu-Chek Active",
            brand: .accuCheck,
            codes: ["meter"],
            kind: .glucoseMeter
          ),
          .init(
            id: "contour_next_one",
            name: "Contour Next One",
            brand: .contour,
            codes: ["contour"],
            kind: .glucoseMeter
          )
        ].filter {
          $0.brand == brand
        }
  }
  
  static func service(for brand: Brand) -> CBUUID {
    let id: String
    
    switch brand {
      case .omron:
        id = "1810"
      case .accuCheck, .contour:
        id = "1808"
    }
    
    return CBUUID(string: id.fullUUID)
  }
}
