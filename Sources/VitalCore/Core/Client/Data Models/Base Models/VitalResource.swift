public enum VitalResource: Equatable {
  public enum Vitals: Equatable {
    case glucose
    case bloodPressure
    case hearthRate
    
    public var logDescription: String {
      switch self {
        case .glucose:
          return "glucose"
        case .bloodPressure:
          return "bloodPressure"
        case .hearthRate:
          return "hearthRate"
      }
    }
  }
  
  case profile
  case body
  case workout
  case activity
  case sleep
  case vitals(Vitals)
  
  public static var all: [VitalResource] = [
    .profile,
    .body,
    .workout,
    .activity,
    .sleep,
    .vitals(.glucose),
    .vitals(.bloodPressure),
    .vitals(.hearthRate)
  ]
  
  public var logDescription: String {
    switch self {
      case .profile:
        return "profile"
      case .body:
        return "body"
      case .workout:
        return "workout"
      case .activity:
        return "activity"
      case .sleep:
        return "sleep"
      case .vitals(let vitals):
        return "vitals - \(vitals.logDescription)"
    }
  }
}
