import VitalCore
extension QuantitySample {
  init(glucose: Glucose) {
    self.init(
      id: String(glucose.id),
      value: glucose.valueUnit,
      startDate: glucose.date,
      endDate: glucose.date,
      type: "automatic",
      unit: "mmol/L"
    )
  }
}
