public enum PostResource {
  public enum Vitals {
    case glucose([QuantitySample])
    case bloodPressure([BloodPressureSample])
    
    public var payload: Encodable {
      switch self {
        case let .glucose(dataPoints):
          return dataPoints
        case let .bloodPressure(dataPoints):
          return dataPoints
      }
    }
    
    public var shouldSkipPost: Bool {
      switch self {
        case let .glucose(samples):
          return samples.isEmpty
        case let .bloodPressure(samples):
          return samples.isEmpty
      }
    }
    
    public var logDescription: String {
      switch self {
        case .bloodPressure:
          return "bloodPressure"
        case .glucose:
          return "glucose"
      }
    }
  }
  
  case profile(ProfilePatch)
  case body(BodyPatch)
  case activity(ActivityPatch)
  case sleep(SleepPatch)
  case workout(WorkoutPatch)
  case vitals(Vitals)
  
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
      case let .vitals(vitals):
        return vitals.payload
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
      case let .vitals(vitals):
        return vitals.shouldSkipPost
    }
  }
  
  public var logDescription: String {
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
        return "workout"
      case let .vitals(vitals):
        return vitals.logDescription
    }
  }
}
