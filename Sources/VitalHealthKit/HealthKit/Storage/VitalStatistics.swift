import HealthKit

struct VitalStatistics {
  var value: Double
  var type: HKQuantityType
  var startDate: Date
  var endDate: Date
  
  init(
    value: Double,
    type: HKQuantityType,
    startDate: Date,
    endDate: Date
  ) {
    self.value = value
    self.type = type
    self.startDate = startDate
    self.endDate = endDate
  }
    
  init(statistics: HKStatistics, type: HKQuantityType, options: HKStatisticsOptions?) throws {
    let unit = type.toHealthKitUnits

    guard
      type.is(compatibleWith: unit),
      let quantity = quantity(for: statistics, with: options, type: type)
    else {
      throw VitalStatisticsError(statistics: statistics)
    }

    let value = quantity.doubleValue(for: unit)
    self.init(
      value: value,
      type: type,
      startDate: statistics.startDate,
      endDate: statistics.endDate
    )
  }
}
