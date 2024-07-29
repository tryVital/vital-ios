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
    switch self {
      case let .summary(summaryData):
        return summaryData.shouldSkipPost
      case let .timeSeries(timeSeriesData):
        return timeSeriesData.shouldSkipPost
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

  public var payload: Encodable {
    switch self {
    case 
      let .glucose(samples), let .bloodOxygen(samples), let .heartRate(samples),
      let .heartRateVariability(samples), let .nutrition(.caffeine(samples)),
      let .nutrition(.water(samples)), let .mindfulSession(samples),
      let .caloriesActive(samples), let .caloriesBasal(samples), let .distance(samples),
      let .floorsClimbed(samples), let .steps(samples), let .vo2Max(samples),
      let .respiratoryRate(samples), let .temperature(samples):
      return samples

    case let .bloodPressure(samples):
      return samples
    }
  }
  
  public var shouldSkipPost: Bool {
    switch self {
    case
      let .glucose(samples), let .bloodOxygen(samples), let .heartRate(samples),
      let .heartRateVariability(samples), let .nutrition(.caffeine(samples)),
      let .nutrition(.water(samples)), let .mindfulSession(samples),
      let .caloriesActive(samples), let .caloriesBasal(samples), let .distance(samples),
      let .floorsClimbed(samples), let .steps(samples), let .vo2Max(samples),
      let .respiratoryRate(samples), let .temperature(samples):
      return samples.isEmpty

    case let .bloodPressure(samples):
      return samples.isEmpty
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
    }
  }
  
  public var shouldSkipPost: Bool {
    switch self {
      case let .profile(patch):
        return patch.dateOfBirth.isNil && patch.height.isNil && patch.biologicalSex.isNil
      case let .body(patch):
        return patch.bodyFatPercentage.isEmpty && patch.bodyMass.isEmpty
      case let .workout(patch):
        return patch.workouts.isEmpty
      case let .activity(patch):
        return patch.activities.isEmpty
      case let .sleep(patch):
        return patch.sleep.isEmpty
      case let .menstrualCycle(patch):
        return patch.cycles.isEmpty
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
    }
  }
}
