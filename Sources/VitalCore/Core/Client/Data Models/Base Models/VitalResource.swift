public enum VitalResource: Equatable, Hashable, Codable {

  @_spi(VitalSDKInternals)
  public init?(_ backfillType: BackfillType) {
    guard let match = VitalResource.all.first(where: { $0.backfillType == backfillType })
      else { return nil }

    self = match
  }

  @_spi(VitalSDKInternals)
  public var priority: Int {
    switch self {
    case .activity, .body, .profile:
      return 1
    case .sleep, .menstrualCycle, .meal:
      return 4
    case .workout, .individual(.vo2Max), .nutrition(.water), .nutrition(.caffeine):
      return 8
    case .electrocardiogram, .heartRateAlert, .afibBurden:
      return 12
    case .vitals(.bloodOxygen), .vitals(.bloodPressure),
        .vitals(.glucose), .vitals(.heartRateVariability),
        .vitals(.mindfulSession), .vitals(.temperature), .vitals(.respiratoryRate):
      return 16
    case .individual(.distanceWalkingRunning), .individual(.steps), .individual(.floorsClimbed):
      return 32
    case .vitals(.heartRate), .individual(.activeEnergyBurned), .individual(.basalEnergyBurned):
      return 64
    case .individual(.exerciseTime), .individual(.weight), .individual(.bodyFat):
      return Int.max
    }
  }

  @_spi(VitalSDKInternals)
  public var backfillType: BackfillType {
    switch self {
    case .activity, .individual(.exerciseTime):
      return BackfillType.activity;
    case .individual(.activeEnergyBurned):
      return BackfillType.caloriesActive
    case .individual(.basalEnergyBurned):
      return BackfillType.caloriesBasal
    case .individual(.distanceWalkingRunning):
      return BackfillType.distance
    case .individual(.steps):
      return BackfillType.steps
    case .individual(.floorsClimbed):
      return BackfillType.floorsClimbed
    case .individual(.vo2Max):
      return BackfillType.vo2Max
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
      return BackfillType.menstrualCycle
    case .vitals(.temperature):
      return BackfillType.temperature
    case .vitals(.respiratoryRate):
      return .respiratoryRate
    case .meal:
      return BackfillType.meal
    case .afibBurden:
      return .afibBurden
    case .electrocardiogram:
      return .electrocardiogram
    case .heartRateAlert:
      return .heartRateAlert
    }
  }

  public enum Vitals: Equatable, Hashable, Codable {
    case glucose
    case bloodPressure
    case bloodOxygen
    case heartRate
    case heartRateVariability
    case mindfulSession
    case respiratoryRate
    case temperature

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
      case .respiratoryRate:
        return "respiratory_rate"
      case .temperature:
        return "temperature"
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
  case meal
  case electrocardiogram
  case heartRateAlert
  case afibBurden

  public static var all: [VitalResource] = [
    .profile,
    .body,
    .workout,
    .activity,
    .sleep,
    .menstrualCycle,
    .meal,

    .vitals(.glucose),
    .vitals(.bloodPressure),
    .vitals(.bloodOxygen),
    .vitals(.heartRate),
    .vitals(.heartRateVariability),
    .vitals(.mindfulSession),
    .vitals(.temperature),
    .vitals(.respiratoryRate),

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

    .electrocardiogram,
    .heartRateAlert,
    .afibBurden,
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
      case .meal:
        return "meal"
      case let .vitals(vitals):
        return vitals.logDescription
      case let .individual(individual):
        return individual.logDescription
      case let .nutrition(nutrition):
        return nutrition.logDescription
    case .electrocardiogram:
      return "electrocardiogram"
    case .heartRateAlert:
      return "heartRateAlert"
    case .afibBurden:
      return "afibBurden"
    }
  }
}

public struct BackfillType: RawRepresentable, Codable, Equatable, Hashable {
  public let rawValue: String

  public init(rawValue: String) {
    self.rawValue = rawValue
  }

  public static let workouts = BackfillType(rawValue: "workouts")
  public static let activity = BackfillType(rawValue: "activity")
  public static let sleep = BackfillType(rawValue: "sleep")
  public static let body = BackfillType(rawValue: "body")
  public static let workoutStream = BackfillType(rawValue: "workout_stream")
  public static let sleepStream = BackfillType(rawValue: "sleep_stream")
  public static let profile = BackfillType(rawValue: "profile")
  public static let bloodPressure = BackfillType(rawValue: "blood_pressure")
  public static let bloodOxygen = BackfillType(rawValue: "blood_oxygen")
  public static let glucose = BackfillType(rawValue: "glucose")
  public static let heartrate = BackfillType(rawValue: "heartrate")
  public static let heartrateVariability = BackfillType(rawValue: "heartrate_variability")
  public static let weight = BackfillType(rawValue: "weight")
  public static let fat = BackfillType(rawValue: "fat")
  public static let meal = BackfillType(rawValue: "meal")
  public static let water = BackfillType(rawValue: "water")
  public static let caffeine = BackfillType(rawValue: "caffeine")
  public static let mindfulnessMinutes = BackfillType(rawValue: "mindfulness_minutes")
  public static let caloriesActive = BackfillType(rawValue: "calories_active")
  public static let caloriesBasal = BackfillType(rawValue: "calories_basal")
  public static let distance = BackfillType(rawValue: "distance")
  public static let floorsClimbed = BackfillType(rawValue: "floors_climbed")
  public static let steps = BackfillType(rawValue: "steps")
  public static let respiratoryRate = BackfillType(rawValue: "respiratory_rate")
  public static let vo2Max = BackfillType(rawValue: "vo2_max")
  public static let stress = BackfillType(rawValue: "stress")
  public static let electrocardiogram = BackfillType(rawValue: "electrocardiogram")
  public static let temperature = BackfillType(rawValue: "temperature")
  public static let menstrualCycle = BackfillType(rawValue: "menstrual_cycle")
  public static let heartRateAlert = BackfillType(rawValue: "heart_rate_alert")
  public static let afibBurden = BackfillType(rawValue: "afib_burden")
}
