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
  case caffeine([QuantitySample])
  case water([QuantitySample])
  
  public var payload: Encodable {
    switch self {
      case let .caffeine(dataPoints):
        return dataPoints
      case let .water(dataPoints):
        return dataPoints
    }
  }
  
  public var shouldSkipPost: Bool {
    switch self {
      case let .caffeine(samples):
        return samples.isEmpty
      case let .water(samples):
        return samples.isEmpty
    }
  }
  
  public var name: String {
    switch self {
      case .caffeine:
        return "caffeine"
      case .water:
        return "water"
    }
  }
}

public enum TimeSeriesData: Equatable, Encodable {
  case glucose([QuantitySample])
  case bloodPressure([BloodPressureSample])
  case heartRate([QuantitySample])
  case nutrition(NutritionData)
  
  
  public var payload: Encodable {
    switch self {
      case let .glucose(dataPoints):
        return dataPoints
      case let .bloodPressure(dataPoints):
        return dataPoints
      case let .heartRate(dataPoints):
        return dataPoints
      case let .nutrition(nutrition):
        return nutrition.payload
    }
  }
  
  public var shouldSkipPost: Bool {
    switch self {
      case let .glucose(samples):
        return samples.isEmpty
      case let .bloodPressure(samples):
        return samples.isEmpty
      case let .heartRate(samples):
        return samples.isEmpty
      case let .nutrition(nutrition):
        return nutrition.shouldSkipPost
    }
  }
  
  public var name: String {
    switch self {
      case .bloodPressure:
        return "blood_pressure"
      case .glucose:
        return "glucose"
      case .heartRate:
        return "heartrate"
      case let .nutrition(nutrition):
        return nutrition.name
    }
  }
}

public enum SummaryData: Equatable, Encodable {
  case profile(ProfilePatch)
  case body(BodyPatch)
  case activity(ActivityPatch)
  case sleep(SleepPatch)
  case workout(WorkoutPatch)
  
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
    }
  }
}
