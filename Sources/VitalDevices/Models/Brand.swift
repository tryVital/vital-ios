import VitalCore

public enum Brand: String, Encodable, Equatable {
  case omron
  case accuChek
  case contour
  case beurer
  case libre
  case oneTouch
  
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
      case .oneTouch:
        return "OneTouch"
    }
  }

  internal var providerSlug: Provider.Slug {
    switch self {
    case .contour:
      return .contourBLE
    case .omron:
      return .omronBLE
    case .accuChek:
      return .accuchekBLE
    case .beurer:
      return .beurerBLE
    case .libre:
      return .libreBLE
    case .oneTouch:
      return .oneTouchBLE
    }
  }
}

public struct DeviceModel: Equatable, Encodable, Identifiable {
  public let name: String
  public let kind: Kind
  public let brand: Brand
  
  public let id: String
  
  public init(
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
  enum Kind: String, Equatable, Encodable {
    case bloodPressure
    case glucoseMeter
  }
}
