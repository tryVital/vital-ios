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
  
  public enum Individual: Equatable {
    case steps
    case activeEnergyBurned
    case basalEnergyBurned
    case floorsClimbed
    case distanceWalkingRunning
    case vo2Max
    
    case weight
    case bodyFat
    
    public var logDescription: String {
      switch self {
        case .steps:
          return "steps"
        case .activeEnergyBurned:
          return "activeEnergyBurned"
        case .basalEnergyBurned:
          return "basalEnergyBurned"
        case .floorsClimbed:
          return "floorsClimbed"
        case .distanceWalkingRunning:
          return "distanceWalkingRunning"
        case .vo2Max:
          return "vo2Max"
        case .weight:
          return "weight"
        case .bodyFat:
          return "bodyFat"
      }
    }
  }
  
  case profile
  case body
  case workout
  case activity
  case sleep
  case vitals(Vitals)
  case individual(Individual)
  
  public static var all: [VitalResource] = [
    .profile,
    .body,
    .workout,
    .activity,
    .sleep,
    
    .vitals(.glucose),
    .vitals(.bloodPressure),
    .vitals(.hearthRate),
    
    .individual(.steps),
    .individual(.floorsClimbed),
    .individual(.distanceWalkingRunning),
    .individual(.vo2Max),
    .individual(.activeEnergyBurned),
    .individual(.basalEnergyBurned),
    .individual(.weight),
    .individual(.bodyFat),
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
      case .individual(let individual):
        return "vitals - \(individual.logDescription)"
    }
  }
}
