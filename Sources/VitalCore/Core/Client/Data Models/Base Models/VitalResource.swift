
// IMPORTANT: Any enum case rename is storage-level breaking change.
// You must include the old name in VitalResource.Type.renamedResources.

public enum VitalResource: Equatable, Hashable, Codable, Sendable {

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
    case .electrocardiogram, .heartRateAlert, .afibBurden, .standHour, .standDuration, .sleepApneaAlert, .sleepBreathingDisturbance, .forcedExpiratoryVolume1, .forcedVitalCapacity, .peakExpiratoryFlowRate, .inhalerUsage, .fall, .uvExposure, .daylightExposure, .handwashing, .basalBodyTemperature:
      return 12
    case .vitals(.bloodOxygen), .vitals(.bloodPressure),
        .vitals(.glucose), .vitals(.heartRateVariability),
        .vitals(.mindfulSession), .vitals(.temperature), .vitals(.respiratoryRate):
      return 16
    case .individual(.distance), .individual(.steps), .individual(.floorsClimbed), .individual(.wheelchairPush):
      return 32
    case .vitals(.heartRate), .individual(.activeEnergyBurned), .individual(.basalEnergyBurned):
      return 64
    case .individual(.exerciseTime), .individual(.weight), .individual(.bodyFat),
        .individual(.waistCircumference), .individual(.bodyMassIndex), .individual(.leanBodyMass):
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
    case .individual(.distance):
      return BackfillType.distance
    case .individual(.steps):
      return BackfillType.steps
    case .individual(.floorsClimbed):
      return BackfillType.floorsClimbed
    case .individual(.vo2Max):
      return BackfillType.vo2Max
    case .body, .individual(.bodyFat), .individual(.weight), .individual(.bodyMassIndex), .individual(.waistCircumference), .individual(.leanBodyMass):
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
    case .standHour:
      return .standHour
    case .standDuration:
      return .standDuration
    case .sleepApneaAlert:
      return .sleepApneaAlert
    case .sleepBreathingDisturbance:
      return .sleepBreathingDisturbance
    case .individual(.wheelchairPush):
      return .wheelchairPush
    case .forcedExpiratoryVolume1:
      return .forcedExpiratoryVolume1
    case .forcedVitalCapacity:
      return .forcedVitalCapacity
    case .peakExpiratoryFlowRate:
      return .peakExpiratoryFlowRate
    case .inhalerUsage:
      return .inhalerUsage
    case .fall:
      return .fall
    case .uvExposure:
      return .uvExposure
    case .daylightExposure:
      return .daylightExposure
    case .handwashing:
      return .handwashing
    case .basalBodyTemperature:
      return .basalBodyTemperature
    }
  }

  public enum Vitals: Equatable, Hashable, Codable, Sendable {
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
  
  public enum Nutrition: Equatable, Hashable, Codable, Sendable {
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
  
  public enum Individual: Equatable, Hashable, Codable, Sendable {
    case steps
    case activeEnergyBurned
    case basalEnergyBurned
    case floorsClimbed
    case distance
    case vo2Max
    case exerciseTime
    case wheelchairPush

    case weight
    case bodyFat
    case leanBodyMass
    case waistCircumference
    case bodyMassIndex

    @available(*, deprecated, renamed: "distance", message: "distanceWalkingRunning has been renamed to distance with the support for Wheelchair Mode")
    public static var distanceWalkingRunning: Self {
      return .distance
    }

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
        case .distance:
          return "distance"
        case .vo2Max:
          return "vo2Max"
        case .exerciseTime:
          return "exerciseTime"
        case .wheelchairPush:
          return "wheelchairPush"
        case .weight:
          return "weight"
      case .bodyFat:
        return "bodyFat"
      case .leanBodyMass:
        return "leanBodyMass"
      case .waistCircumference:
        return "waistCircumference"
      case .bodyMassIndex:
        return "bodyMassIndex"
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
  case standHour
  case standDuration
  case sleepApneaAlert
  case sleepBreathingDisturbance
  case forcedExpiratoryVolume1
  case forcedVitalCapacity
  case peakExpiratoryFlowRate
  case inhalerUsage
  case fall
  case uvExposure
  case daylightExposure
  case handwashing
  case basalBodyTemperature

  public static let all: [VitalResource] = [
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
    .individual(.wheelchairPush),
    .individual(.floorsClimbed),
    .individual(.distance),
    .individual(.vo2Max),
    .individual(.activeEnergyBurned),
    .individual(.basalEnergyBurned),
    .individual(.exerciseTime),
    .individual(.weight),
    .individual(.bodyFat),
    .individual(.leanBodyMass),
    .individual(.waistCircumference),
    .individual(.bodyMassIndex),

    .nutrition(.water),
    .nutrition(.caffeine),

    .electrocardiogram,
    .heartRateAlert,
    .afibBurden,
    .standHour,
    .standDuration,
    .sleepApneaAlert,
    .sleepBreathingDisturbance,
    .forcedExpiratoryVolume1,
    .forcedVitalCapacity,
    .peakExpiratoryFlowRate,
    .inhalerUsage,
    .fall,
    .uvExposure,
    .daylightExposure,
    .handwashing,
    .basalBodyTemperature
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
    case .standHour:
      return "standHour"
    case .standDuration:
      return "standDuration"
    case .sleepApneaAlert:
      return "sleepApneaAlert"
    case .sleepBreathingDisturbance:
      return "sleepBreathingDisturbance"
    case .forcedExpiratoryVolume1:
      return "forcedExpiratoryVolume1"
    case .forcedVitalCapacity:
      return "forcedVitalCapacity"
    case .peakExpiratoryFlowRate:
      return "peakExpiratoryFlowRate"
    case .inhalerUsage:
      return "inhalerUsage"
    case .fall:
      return "fall"
    case .uvExposure:
      return "uvExposure"
    case .daylightExposure:
      return "daylightExposure"
    case .handwashing:
      return "handwashing"
    case .basalBodyTemperature:
      return "basalBodyTemperature"
    }
  }
}

public struct BackfillType: RawRepresentable, Codable, Equatable, Hashable, Sendable {
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
  public static let standHour = BackfillType(rawValue: "stand_hour")
  public static let standDuration = BackfillType(rawValue: "stand_duration")
  public static let sleepApneaAlert = BackfillType(rawValue: "sleep_apnea_alert")
  public static let sleepBreathingDisturbance = BackfillType(rawValue: "sleep_breathing_disturbance")
  public static let wheelchairPush = BackfillType(rawValue: "wheelchair_push")
  public static let forcedExpiratoryVolume1 = BackfillType(rawValue: "forced_expiratory_volume_1")
  public static let forcedVitalCapacity = BackfillType(rawValue: "forced_vital_capacity")
  public static let peakExpiratoryFlowRate = BackfillType(rawValue: "peak_expiratory_flow_rate")
  public static let inhalerUsage = BackfillType(rawValue: "inhaler_usage")
  public static let fall = BackfillType(rawValue: "fall")
  public static let uvExposure = BackfillType(rawValue: "uv_exposure")
  public static let daylightExposure = BackfillType(rawValue: "daylight_exposure")
  public static let handwashing = BackfillType(rawValue: "handwashing")
  public static let basalBodyTemperature = BackfillType(rawValue: "basal_body_temperature")
}

extension VitalResource {
  // Current Name -> Old Name
  private static let renamedResources: [VitalResource: String] = [
    .vitals(.heartRate): "vitals(VitalCore.VitalResource.Vitals.hearthRate)",
    .individual(.distance): "individual(VitalCore.VitalResource.Individual.distanceWalkingRunning)",
  ]

  @_spi(VitalSDKInternals)
  public var storageReadKeys: [String] {
    // Current name must go first in order
    var keys = [String(describing: self)]

    // Historical name goes next; only lookup when the current name misses.
    if let key = Self.renamedResources[self] {
      keys.append(key)
    }
    return keys
  }

  @_spi(VitalSDKInternals)
  public var storageWriteKey: String {
    return String(describing: self)
  }
}
