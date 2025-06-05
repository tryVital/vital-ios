import VitalCore
import HealthKit

func handleElectrocardiogram(
  healthKitStore: HKHealthStore,
  vitalStorage: AnchorStorage,
  instruction: SyncInstruction
) async throws -> (electrocardiograms: [ManualElectrocardiogram], anchors: [StoredAnchor]) {

  let (ecg, anchor) = try await anchoredQuery(
    healthKitStore: healthKitStore,
    vitalStorage: vitalStorage,
    type: HKElectrocardiogramType.electrocardiogramType(),
    sampleClass: HKElectrocardiogram.self,
    unit: (),
    limit: AnchoredQueryChunkSize.electrocardiogram,
    startDate: instruction.query.lowerBound,
    endDate: instruction.query.upperBound,
    transform: { sample, _ in sample }
  )

  var electrocardiogram = [ManualElectrocardiogram]()

  for ecg in ecg {
    let handle = CancellableQueryHandle { continuation in
      var offsets = [Int]()
      var lead1 = [Double?]()

      offsets.reserveCapacity(ecg.numberOfVoltageMeasurements)
      lead1.reserveCapacity(ecg.numberOfVoltageMeasurements)

      let query = HKElectrocardiogramQuery(ecg) { query, result in
        switch result {
        case .done:
          continuation.resume(returning: (offsets, lead1))

        case let .error(error):
          continuation.resume(throwing: error)

        case let .measurement(measurement):
          offsets.append(Int(measurement.timeSinceSampleStart * 1000))
          lead1.append(
            measurement.quantity(for: .appleWatchSimilarToLeadI)?
              .doubleValue(for: .voltUnit(with: .milli))
          )
        @unknown default:
          break
        }
      }

      return query
    }

    let (offsets, lead1) = try await handle.execute(in: healthKitStore)

    let (classification, inconclusiveCause) = ManualElectrocardiogram.mapClassification(
      ecg.classification
    )

    let summary = ManualElectrocardiogram.Summary(
      id: ecg.uuid.uuidString,
      sessionStart: ecg.startDate,
      sessionEnd: ecg.endDate,
      voltageSampleCount: ecg.numberOfVoltageMeasurements,
      heartRateMean: (ecg.averageHeartRate?.doubleValue(for: .count().unitDivided(by: .minute()))).map(Int.init),
      samplingFrequencyHz: ecg.samplingFrequency?.doubleValue(for: .hertz()),
      classification: classification,
      inconclusiveCause: inconclusiveCause,
      algorithmVersion: ecg.metadata?[HKMetadataKeyAppleECGAlgorithmVersion] as? String,
      sourceBundle: ecg.sourceRevision.source.bundleIdentifier,
      productType: ecg.sourceRevision.productType,
      deviceModel: ecg.device?.model,
      metadata: sampleMetadata(ecg)
    )

    let voltageData = ManualElectrocardiogram.VoltageData(
      sessionStartOffsetMillisecond: offsets, lead1: lead1
    )

    electrocardiogram.append(
      ManualElectrocardiogram(electrocardiogram: summary, voltageData: voltageData)
    )
  }

  var anchors = [StoredAnchor]()
  anchors.appendOptional(anchor)

  return (electrocardiogram, anchors)
}
