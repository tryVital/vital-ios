public enum VitalResource: Equatable, Hashable, Codable {
  public enum Vitals: Equatable, Hashable, Codable {
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
  
  public enum Nutrition: Equatable, Hashable, Codable {
    case water
    case caffeine
    
    public var logDescription: String {
      switch self {
        case .water:
          return "water"
        case .caffeine:
          return "caffeine"
      }
    }
  }
  
  public enum Individual: Equatable, Hashable, Codable {
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
  case nutrition(Nutrition)
  
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
    
    .nutrition(.water),
    .nutrition(.caffeine),
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
      case let .vitals(vitals):
        return "vitals - \(vitals.logDescription)"
      case let .individual(individual):
        return "individual - \(individual.logDescription)"
      case let .nutrition(nutrition):
        return "nutrition - \(nutrition.logDescription)"
    }
  }
}
