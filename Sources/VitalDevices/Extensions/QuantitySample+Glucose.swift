import VitalCore

/// We use this approach so that the JSON payload for `LocalQuantitySample`
/// looks nicer:
///
/// ```
/// {
///  "metadata": {
///   "glucose": {
///   ...
///   }
///  }
/// }
private struct FreestyleLibreGlucoseDigest: Encodable {
  struct Digest: Encodable {
    let rawValue: Int
    let rawTemperature: Int
    let temperatureAdjustment: Int
    let hasError: Bool
    let dataQuality: Glucose.DataQuality
    let dataQualityFlags: Int

    init(glucose: Glucose) {
      self.rawValue = glucose.rawValue
      self.rawTemperature = glucose.rawTemperature
      self.temperatureAdjustment = glucose.temperatureAdjustment
      self.hasError = glucose.hasError
      self.dataQuality = glucose.dataQuality
      self.dataQualityFlags = glucose.dataQualityFlags
    }
  }

  let glucose: Digest

  init(glucose: Glucose) {
    self.glucose = Digest(glucose: glucose)
  }
}

extension LocalQuantitySample {
  init(glucose: Glucose) {
    self.init(
      value: glucose.valueUnit,
      startDate: glucose.date,
      endDate: glucose.date,
      type: .manualScan,
      unit: .glucose
    )
  }
}
