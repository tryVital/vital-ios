import HealthKit
import VitalCore

public enum DataInput {
  case water(milliliters: Int)
  case coffee(grams: Int)
  
  var value: Int {
    switch self {
      case let .water(milliliters):
        return milliliters
      case let .coffee(grams):
        return grams
    }
  }
  
  var units: HKUnit {
    switch self {
      case .water:
        return .literUnit(with: .milli)
      case .coffee:
        return .gram()
    }
  }
  
  var type: HKQuantityType {
    switch self {
      case .water:
        return .quantityType(forIdentifier: .dietaryWater)!
      case .coffee:
        return .quantityType(forIdentifier: .dietaryCaffeine)!
    }
  }
}

public enum WritableVitalResource {
  case caffeine
  case water
  
  var toResource: VitalResource {
    switch self {
      case .caffeine:
        return .nutrition(.caffeine)
        
      case .water:
        return .nutrition(.water)
    }
  }
}
