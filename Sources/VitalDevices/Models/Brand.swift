public enum Brand {
  case omron
  case accuCheck
  case contour
  
  public var name: String {
    switch self {
      case .contour:
        return "Contour"
      case .omron:
        return "Omron"
      case .accuCheck:
        return "Accu-Chek"
    }
  }
}

public struct DeviceModel {
  public let name: String
  public let kind: Kind
  public let brand: Brand

  let id: String
  let codes: [String]
  
  init(
    id: String,
    name: String,
    brand: Brand,
    codes: [String],
    kind: Kind
  ) {
    self.id = id
    self.name = name
    self.brand = brand
    self.codes = codes
    self.kind = kind
  }
}

public extension DeviceModel {
  enum Kind {
    case bloodPressure
    case glucoseMeter
  }
}
