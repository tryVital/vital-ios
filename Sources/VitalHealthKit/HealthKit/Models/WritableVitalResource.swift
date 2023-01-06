import HealthKit
import VitalCore

public enum DataInput {
  case water(milliliters: Int)
  case caffeine(grams: Int)

  var value: Int {
    switch self {
      case let .water(milliliters):
        return milliliters

      case let .caffeine(grams: grams):
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
      case .caffeine:
        return .nutrition(.caffeine)
    }
  }
}

public enum WritableVitalResource {
  case water
  case caffeine
  
  var toResource: VitalResource {
    switch self {        
      case .water:
        return .nutrition(.water)
      case .caffeine:
        return .nutrition(.caffeine)
    }
  }
}
