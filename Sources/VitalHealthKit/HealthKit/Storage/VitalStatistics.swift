import HealthKit

struct VitalStatistics {
  var value: Double
  var type: HKQuantityType
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
    type: HKQuantityType,
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
    
  init(statistics: HKStatistics, type: HKQuantityType, sources: [String]) throws {
    let unit = type.toHealthKitUnits

    guard
      type.is(compatibleWith: unit),
      let quantity = type.idealStatisticalQuantity(from: statistics)
    else { throw VitalStatisticsError(statistics: statistics) }
    
    let value = quantity.doubleValue(for: unit)
    self.init(
      value: value,
      type: type,
      startDate: statistics.startDate,
      endDate: statistics.endDate,
      sources: sources
    )
  }

  func withSampleDates(first: Date, last: Date) -> Self {
    var copy = self
    copy.firstSampleDate = first
    copy.lastSampleDate = last
    return copy
  }
}
