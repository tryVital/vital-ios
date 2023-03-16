import HealthKit

struct VitalStatistics {
  var value: Double
  var type: String
  var startDate: Date
  var endDate: Date
  
  var sources: [String]
  
  var firstSampleDate: Date?
  var lastSampleDate: Date?
  
  var sourcesValue: String {
    return sources.joined(separator: ",")
  }
  
  init(
    value: Double,
    type: String,
    startDate: Date,
    endDate: Date,
    sources: [String]
  ) {
    self.value = value
    self.type = type
    self.startDate = startDate
    self.endDate = endDate
    self.sources = sources
  }
    
  init?(statistics: HKStatistics, type: HKQuantityType, sources: [String]) {
    guard let sum = statistics.sumQuantity() else {
      return nil
    }
    
    let value = sum.doubleValue(for: type.toHealthKitUnits)
    self.init(
      value: value,
      type: String(describing: type),
      startDate: statistics.startDate,
      endDate: statistics.endDate,
      sources: sources
    )
  }
}
