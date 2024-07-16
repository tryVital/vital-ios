public enum VitalResource: Equatable, Hashable, Codable {
  public func resourceToBackfillType() -> BackfillType {
    switch self{
    case .activity, .individual(.activeEnergyBurned), .individual(.basalEnergyBurned), .individual(.distanceWalkingRunning), .individual(.exerciseTime), .individual(.floorsClimbed), .individual(.steps), .individual(.vo2Max):
      return BackfillType.activity;
    case .body, .individual(.bodyFat), .individual(.weight):
      return BackfillType.body;
    case .vitals(.bloodOxygen):
      return BackfillType.bloodOxygen;
    case .vitals(.bloodPressure):
      return BackfillType.bloodPressure;
    case .vitals(.glucose):
      return BackfillType.glucose;
    case .vitals(.heartRate):
      return BackfillType.heartrate;
    case .vitals(.heartRateVariability):
      return BackfillType.heartrateVariability;
    case .profile:
      return BackfillType.profile;
    case .sleep:
      return BackfillType.sleep;
    case .nutrition(.water):
      return BackfillType.water;
    case .nutrition(.caffeine):
      return BackfillType.caffeine;
    case .vitals(.mindfulSession):
      return BackfillType.mindfulnessMinutes;
    case .workout:
      return BackfillType.workouts;
    case .menstrualCycle:
      return BackfillType.menstrualCycle;
    }
  }

  public enum Vitals: Equatable, Hashable, Codable {
    case glucose
    case bloodPressure
    case bloodOxygen
    case heartRate
    case heartRateVariability
    case mindfulSession
    
    public var logDescription: String {
      switch self {
        case .glucose:
          return "glucose"
        case .bloodPressure:
          return "bloodPressure"
        case .bloodOxygen:
          return "bloodOxygen"
        case .heartRate:
          return "heartRate"
        case .heartRateVariability:
          return "heartRateVariability"
        case .mindfulSession:
          return "mindfulSession"
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
    case exerciseTime
    
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
        case .exerciseTime:
          return "exerciseTime"
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
  case menstrualCycle
  case vitals(Vitals)
  case individual(Individual)
  case nutrition(Nutrition)
  
  public static var all: [VitalResource] = [
    .profile,
    .body,
    .workout,
    .activity,
    .sleep,
    .menstrualCycle,

    .vitals(.glucose),
    .vitals(.bloodPressure),
    .vitals(.bloodOxygen),
    .vitals(.heartRate),
    .vitals(.heartRateVariability),
    .vitals(.mindfulSession),
    
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
      case .menstrualCycle:
        return "menstrualCycle"
      case let .vitals(vitals):
        return "vitals - \(vitals.logDescription)"
      case let .individual(individual):
        return "individual - \(individual.logDescription)"
      case let .nutrition(nutrition):
        return "nutrition - \(nutrition.logDescription)"
    }
  }
}

public enum BackfillType: String, Codable {
  case workouts = "workouts"
  case activity = "activity"
  case sleep = "sleep"
  case body = "body"
  case workoutStream = "workout_stream"
  case sleepStream = "sleep_stream"
  case profile = "profile"
  case bloodPressure = "blood_pressure"
  case bloodOxygen = "blood_oxygen"
  case glucose = "glucose"
  case heartrate = "heartrate"
  case heartrateVariability = "heartrate_variability"
  case weight = "weight"
  case fat = "fat"
  case meal = "meal"
  case water = "water"
  case caffeine = "caffeine"
  case mindfulnessMinutes = "mindfulness_minutes"
  case caloriesActive = "calories_active"
  case distance = "distance"
  case steps = "steps"
  case respiratoryRate = "respiratory_rate"
  case vo2Max = "vo2_max"
  case stress = "stress"
  case electrocardiogram = "electrocardiogram"
  case temperature = "temperature"
  case menstrualCycle = "menstrual_cycle"
}
