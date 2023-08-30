
public enum SourceType: String, RawRepresentable, Codable {
  case unknown
  case phone
  case watch
  case app
  case multipleSources = "multiple_sources"

  case manualScan = "manual_scan"
  case cuff
  case fingerprick
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
      if productType.starts(with: "phone") {
        return .phone
      }
      return .unknown
    }

    return .unknown
  }
}
