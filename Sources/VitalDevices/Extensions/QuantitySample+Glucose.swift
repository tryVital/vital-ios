import VitalCore

/// We use this approach so that the JSON payload for `QuantitySample`
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

extension QuantitySample {
  init(glucose: Glucose) {
    self.init(
      id: String(glucose.id),
      value: glucose.valueUnit,
      startDate: glucose.date,
      endDate: glucose.date,
      type: "automatic",
      unit: "mmol/L",
      metadata: FreestyleLibreGlucoseDigest(glucose: glucose)
        .eraseToAnyEncodable()
    )
  }
}
