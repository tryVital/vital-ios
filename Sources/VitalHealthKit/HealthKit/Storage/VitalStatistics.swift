import HealthKit

struct VitalStatistics {
  var value: Double
  var type: String
  var startDate: Date
  var endDate: Date
  
  init(value: Double, type: String, startDate: Date, endDate: Date) {
    self.value = value
    self.type = type
    self.startDate = startDate
    self.endDate = endDate
  }
    
  init?(statistics: HKStatistics, type: HKQuantityType) {
    guard let sum = statistics.sumQuantity() else {
      return nil
    }
    
    let value = sum.doubleValue(for: type.toHealthKitUnits)
    self.init(
      value: value,
      type: String(describing: type),
      startDate: statistics.startDate,
      endDate: statistics.endDate
    )
  }
}
