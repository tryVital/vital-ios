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
    
  init?(statistics: HKStatistics, unit: QuantityUnit, type: HKQuantityType, options: HKStatisticsOptions?) {

    guard
      let quantity = quantity(for: statistics, with: options, type: type)
    else {
      // 2026-03-09
      // It seems HealthKit starts returning HKStatistics that report nil rather than zero HKQuantity, or
      // not returning the HKStatistics at all.
      return nil
    }

    let value = quantity.doubleValue(for: unit.healthKitRepresentation)
    self.init(
      value: value,
      type: type,
      startDate: statistics.startDate,
      endDate: statistics.endDate
    )
  }
}
