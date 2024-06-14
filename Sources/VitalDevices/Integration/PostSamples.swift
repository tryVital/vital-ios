@_spi(VitalSDKInternals) import VitalCore


internal func postGlucose(_ provider: Provider.Slug, samples: [LocalQuantitySample]) {
  guard !samples.isEmpty else { return }

  Task {
    do {
      try await postGlucoseImpl(provider, samples: samples)
      VitalLogger.devices.info("posted \(samples.count) glucose for \(provider)", source: "PostSamples")

    } catch let error {
      VitalLogger.devices.error("failed to post \(samples.count) glucose for \(provider): \(error)", source: "PostSamples")
    }
  }
}


internal func postBloodPressure(_ provider: Provider.Slug, samples: [LocalBloodPressureSample]) {
  guard !samples.isEmpty else { return }

  Task {
    do {
      try await postBloodPressureImpl(provider, samples: samples)
      VitalLogger.devices.info("posted \(samples.count) BP for \(provider)", source: "PostSamples")

    } catch let error {
      VitalLogger.devices.error("failed to post \(samples.count) BP for \(provider): \(error)", source: "PostSamples")
    }
  }
}


private func postGlucoseImpl(_ provider: Provider.Slug, samples: [LocalQuantitySample]) async throws {
  guard VitalClient.status.contains(.signedIn) else {
    return
  }

  try await VitalClient.shared.checkConnectedSource(for: provider)
  try await VitalClient.shared.timeSeries.post(
    .glucose(samples),
    stage: .daily,
    provider: provider,
    timeZone: .current
  )
}


private func postBloodPressureImpl(_ provider: Provider.Slug, samples: [LocalBloodPressureSample]) async throws {
  guard VitalClient.status.contains(.signedIn) else {
    return
  }

  try await VitalClient.shared.checkConnectedSource(for: provider)
  try await VitalClient.shared.timeSeries.post(
    .bloodPressure(samples),
    stage: .daily,
    provider: provider,
    timeZone: .current
  )
}
