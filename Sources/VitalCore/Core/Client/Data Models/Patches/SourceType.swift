
public enum SourceType: Hashable, RawRepresentable, Codable {
  public init(rawValue: String) {
    switch rawValue {
    case "unknown":
      self = .unknown
    case "phone":
      self = .phone
    case "watch":
      self = .watch
    case "app":
      self = .app
    case "ring":
      self = .ring
    case "multiple_sources":
      self = .multipleSources
    case "manual_scan":
      self = .manualScan
    case "cuff":
      self = .cuff
    case "fingerprick":
      self = .fingerprick
    case "chest_strap":
      self = .chestStrap
    case "automatic":
      self = .automatic
    case let rawValue:
      self = .unrecognized(rawValue)
    }
  }
  
  case unknown
  case phone
  case watch
  case app
  case ring
  case chestStrap
  case multipleSources

  case automatic
  case manualScan
  case cuff
  case fingerprick

  case unrecognized(String)

  public var rawValue: String {
    switch self {
    case .unknown:
      return "unknown"
    case .app:
      return "app"
    case .phone:
      return "phone"
    case .watch:
      return "watch"
    case .ring:
      return "ring"
    case .chestStrap:
      return "chest_strap"
    case .multipleSources:
      return "multiple_sources"
    case .automatic:
      return "automatic"
    case .manualScan:
      return "manual_scan"
    case .cuff:
      return "cuff"
    case .fingerprick:
      return "fingerprick"
    case let .unrecognized(rawValue):
      return rawValue
    }
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    self.init(rawValue: try container.decode(String.self))
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(rawValue)
  }

  public static func ==(lhs: Self, rhs: Self) -> Bool {
    lhs.rawValue == rhs.rawValue
  }

  public func hash(into hasher: inout Hasher) {
    hasher.combine(rawValue)
  }
}

extension SourceType {
  public static func infer(sourceBundle: String?, productType: String?) -> SourceType {
    guard let sourceBundle = sourceBundle else {
      return .unknown
    }

    if sourceBundle == "com.apple.Health" {
      return .app
    }

    if sourceBundle.starts(with: "com.apple.health.") {
      let productType = (productType ?? "").lowercased()
      if productType.starts(with: "watch") {
        return .watch
      }
      if productType.starts(with: "iphone") {
        return .phone
      }
      return .unknown
    }

    return .unknown
  }
}
