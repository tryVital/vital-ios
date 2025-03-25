public enum ProcessedResourceData: Equatable, Encodable {
  case summary(SummaryData)
  case timeSeries(TimeSeriesData)
  
  public var payload: Encodable {
    switch self {
      case let .summary(summaryData):
        return summaryData.payload
      case let .timeSeries(timeSeriesData):
        return timeSeriesData.payload
    }
  }

  public var shouldSkipPost: Bool {
    dataCount == 0
  }

  public var dataCount: Int {
    switch self {
      case let .summary(summaryData):
        return summaryData.dataCount
      case let .timeSeries(timeSeriesData):
        return timeSeriesData.dataCount
    }
  }

  public var name: String {
    switch self {
      case let .summary(summaryData):
        return summaryData.name
      case let .timeSeries(timeSeriesData):
        return timeSeriesData.name
    }
  }
}

public enum NutritionData: Equatable, Encodable {
  case water([LocalQuantitySample])
  case caffeine([LocalQuantitySample])
  
  public var payload: Encodable {
    switch self {
      case let .water(dataPoints):
        return dataPoints
      case let .caffeine(dataPoints):
        return dataPoints
    }
  }
  
  public var shouldSkipPost: Bool {
    switch self {
      case let .water(samples):
        return samples.isEmpty
      case let .caffeine(samples):
        return samples.isEmpty
    }
  }
  
  public var name: String {
    switch self {
      case .water:
        return "water"
      case .caffeine:
        return "caffeine"
    }
  }
}

public enum TimeSeriesData: Equatable, Encodable {
  case glucose([LocalQuantitySample])
  case bloodOxygen([LocalQuantitySample])
  case bloodPressure([LocalBloodPressureSample])
  case heartRate([LocalQuantitySample])
  case heartRateVariability([LocalQuantitySample])
  case nutrition(NutritionData)
  case mindfulSession([LocalQuantitySample])
  case respiratoryRate([LocalQuantitySample])
  case caloriesActive([LocalQuantitySample])
  case caloriesBasal([LocalQuantitySample])
  case distance([LocalQuantitySample])
  case floorsClimbed([LocalQuantitySample])
  case steps([LocalQuantitySample])
  case vo2Max([LocalQuantitySample])
  case temperature([LocalQuantitySample])
  case afibBurden([LocalQuantitySample])
  case heartRateAlert([LocalQuantitySample])
  case standHour([LocalQuantitySample])
  case standTime([LocalQuantitySample])
  case sleepApneaAlert([LocalQuantitySample])
  case sleepBreathingDisturbance([LocalQuantitySample])
  case swimmingStroke([LocalQuantitySample])
  case wheelchairPush([LocalQuantitySample])
  case forcedExpiratoryVolume1([LocalQuantitySample])
  case forcedVitalCapacity([LocalQuantitySample])
  case peakExpiratoryFlowRate([LocalQuantitySample])
  case inhalerUsage([LocalQuantitySample])
  case fall([LocalQuantitySample])
  case uvExposure([LocalQuantitySample])
  case daylightExposure([LocalQuantitySample])
  case handwashing([LocalQuantitySample])
  case basalBodyTemperature([LocalQuantitySample])

  public var payload: Encodable {
    switch self {
    case 
      let .glucose(samples), let .bloodOxygen(samples), let .heartRate(samples),
      let .heartRateVariability(samples), let .nutrition(.caffeine(samples)),
      let .nutrition(.water(samples)), let .mindfulSession(samples),
      let .caloriesActive(samples), let .caloriesBasal(samples), let .distance(samples),
      let .floorsClimbed(samples), let .steps(samples), let .vo2Max(samples),
      let .respiratoryRate(samples), let .temperature(samples), let .afibBurden(samples),
      let .heartRateAlert(samples), let .standHour(samples), let .standTime(samples), let .sleepApneaAlert(samples),
      let .sleepBreathingDisturbance(samples), let .swimmingStroke(samples), let .wheelchairPush(samples), let .forcedExpiratoryVolume1(samples),
      let .forcedVitalCapacity(samples), let .peakExpiratoryFlowRate(samples), let .inhalerUsage(samples), let .fall(samples),
      let .uvExposure(samples), let .daylightExposure(samples), let .handwashing(samples), let .basalBodyTemperature(samples):
      return samples

    case let .bloodPressure(samples):
      return samples
    }
  }
  
  public var dataCount: Int {
    switch self {
    case
      let .glucose(samples), let .bloodOxygen(samples), let .heartRate(samples),
      let .heartRateVariability(samples), let .nutrition(.caffeine(samples)),
      let .nutrition(.water(samples)), let .mindfulSession(samples),
      let .caloriesActive(samples), let .caloriesBasal(samples), let .distance(samples),
      let .floorsClimbed(samples), let .steps(samples), let .vo2Max(samples),
      let .respiratoryRate(samples), let .temperature(samples), let .afibBurden(samples),
      let .heartRateAlert(samples), let .standHour(samples), let .standTime(samples), let .sleepApneaAlert(samples),
      let .sleepBreathingDisturbance(samples), let .swimmingStroke(samples), let .wheelchairPush(samples), let .forcedExpiratoryVolume1(samples),
      let .forcedVitalCapacity(samples), let .peakExpiratoryFlowRate(samples), let .inhalerUsage(samples), let .fall(samples),
      let .uvExposure(samples), let .daylightExposure(samples), let .handwashing(samples), let .basalBodyTemperature(samples):
      return samples.count

    case let .bloodPressure(samples):
      return samples.count
    }
  }
  
  public var name: String {
    switch self {
      case .bloodPressure:
        return "blood_pressure"
      case .bloodOxygen:
        return "blood_oxygen"
      case .glucose:
        return "glucose"
      case .heartRate:
        return "heartrate"
      case .heartRateVariability:
        return "heartrate_variability"
      case let .nutrition(nutrition):
        return nutrition.name
      case .mindfulSession:
        /// This is the path used by the endpoint
        /// so it needs to be `mindfulness_minutes` versus `mindful_session`.
        return "mindfulness_minutes"
    case .caloriesActive:
      return "calories_active"
    case .caloriesBasal:
      return "calories_basal"
    case .distance:
      return "distance"
    case .floorsClimbed:
      return "floors_climbed"
    case .steps:
      return "steps"
    case .vo2Max:
      return "vo2_max"
    case .respiratoryRate:
      return "respiratory_rate"
    case .temperature:
      return "temperature"
    case .afibBurden:
      return "afib_burden"
    case .heartRateAlert:
      return "heart_rate_alert"
    case .standHour:
      return "stand_hour"
    case .standTime:
      return "stand_duration"
    case .sleepApneaAlert:
      return "sleep_apnea_alert"
    case .sleepBreathingDisturbance:
      return "sleep_breathing_disturbance"
    case .swimmingStroke:
      return "swimming_stroke"
    case .wheelchairPush:
      return "wheelchair_push"
    case .forcedExpiratoryVolume1:
      return "forced_expiratory_volume_1"
    case .forcedVitalCapacity:
      return "forced_vital_capacity"
    case .peakExpiratoryFlowRate:
      return "peak_expiratory_flow_rate"
    case .inhalerUsage:
      return "inhaler_usage"
    case .fall:
      return "fall"
    case .uvExposure:
      return "uv_exposure"
    case .daylightExposure:
      return "daylight_exposure"
    case .handwashing:
      return "handwashing"
    case .basalBodyTemperature:
      return "basal_body_temperature"
    }
  }
}

public enum SummaryData: Equatable, Encodable {
  case profile(ProfilePatch)
  case body(BodyPatch)
  case activity(ActivityPatch)
  case sleep(SleepPatch)
  case workout(WorkoutPatch)
  case menstrualCycle(MenstrualCyclePatch)
  case meal(MealPatch)
  case electrocardiogram([ManualElectrocardiogram])

  public var payload: Encodable {
    switch self {
      case let .profile(patch):
        return patch
      case let .body(patch):
        return patch
      case let .activity(patch):
        return patch.activities
      case let .sleep(patch):
        return patch.sleep
      case let .workout(patch):
        return patch.workouts
      case let .menstrualCycle(patch):
        return patch.cycles
      case let .meal(patch):
        return patch.meals
      case let .electrocardiogram(ecgs):
        return ecgs
    }
  }
  
  public var dataCount: Int {
    switch self {
      case let .profile(patch):
        return patch.dateOfBirth.isNil && patch.height.isNil && patch.biologicalSex.isNil ? 0 : 1
      case let .body(patch):
        return patch.bodyFatPercentage.count + patch.bodyMass.count
      case let .workout(patch):
        return patch.workouts.count
      case let .activity(patch):
        return patch.activities.count
      case let .sleep(patch):
        return patch.sleep.count
      case let .menstrualCycle(patch):
        return patch.cycles.count
      case let .meal(patch):
        return patch.dataCount()
      case let .electrocardiogram(ecgs):
        return ecgs.count
    }
  }
  
  public var name: String {
    switch self {
      case .activity:
        return "activity"
      case .body:
        return "body"
      case .profile:
        return "profile"
      case .sleep:
        return "sleep"
      case .workout:
        return "workouts"
      case .menstrualCycle:
        return "menstrual_cycle"
      case .meal:
        return "meal"
      case .electrocardiogram:
        return "electrocardiogram"
    }
  }
}
