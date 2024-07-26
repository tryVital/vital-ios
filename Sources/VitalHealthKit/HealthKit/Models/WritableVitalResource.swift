import HealthKit
import VitalCore

public enum DataInput {
  case water(milliliters: Int)
  case caffeine(grams: Int)
  case mindfulSession

  var value: Int {
    switch self {
      case let .water(milliliters):
        return milliliters

      case let .caffeine(grams: grams):
        return grams

      case .mindfulSession:
        fatalError("mindful session has no data associated with")
    }
  }
  
  var type: HKQuantityType {
    let requirements = toHealthKitTypes(resource: resource)
    guard requirements.isIndividualType, let type = requirements.required.first as? HKQuantityType else {
      fatalError("This is a developer error. No type for \(self)")
    }
    
    return type
  }
  
  var resource: VitalResource {
    switch self {
      case .mindfulSession:
        return .vitals(.mindfulSession)
      case .water:
        return .nutrition(.water)
      case .caffeine:
        return .nutrition(.caffeine)
    }
  }
}

public enum WritableVitalResource {
  case water
  case caffeine
  case mindfulSession
  
  var toResource: VitalResource {
    switch self {        
      case .water:
        return .nutrition(.water)
      case .caffeine:
        return .nutrition(.caffeine)
      case .mindfulSession:
        return .vitals(.mindfulSession)
    }
  }
}
