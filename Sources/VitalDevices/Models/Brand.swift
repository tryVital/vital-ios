public enum Brand: Encodable, Equatable {
  case omron
  case accuChek
  case contour
  case beurer
  case libre
  
  public var name: String {
    switch self {
      case .contour:
        return "Contour"
      case .omron:
        return "Omron"
      case .accuChek:
        return "Accu-Chek"
      case .beurer:
        return "Beurer"
      case .libre:
        return "FreeStyle Libre"
    }
  }
}

public struct DeviceModel: Equatable, Encodable, Identifiable {
  public let name: String
  public let kind: Kind
  public let brand: Brand
  
  public let id: String
  
  init(
    id: String,
    name: String,
    brand: Brand,
    kind: Kind
  ) {
    self.id = id
    self.name = name
    self.brand = brand
    self.kind = kind
  }
}

public extension DeviceModel {
  enum Kind: Equatable, Encodable {
    case bloodPressure
    case glucoseMeter
  }
}
