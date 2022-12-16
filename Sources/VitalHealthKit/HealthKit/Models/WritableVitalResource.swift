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
    return type.toHealthKitUnits
  }
  
  var type: HKQuantityType {
    let types = toHealthKitTypes(resource: resource)
    guard let type = types.first as? HKQuantityType else {
      fatalError("This is a developer error. No type for \(self)")
    }
    
    return type
  }
  
  var resource: VitalResource {
    switch self {
      case .water:
        return .nutrition(.water)
      case .coffee:
        return .nutrition(.caffeine)
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
