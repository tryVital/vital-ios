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
    let stream = AsyncThrowingStream<(TimeInterval, Double?), any Error> { continuation in
      let query = HKElectrocardiogramQuery(ecg) { query, result in
        switch result {
        case .done:
          continuation.finish()
        case let .error(error):
          continuation.finish(throwing: error)
        case let .measurement(measurement):
          continuation.yield((
            measurement.timeSinceSampleStart,
            measurement.quantity(for: .appleWatchSimilarToLeadI)?
              .doubleValue(for: .voltUnit(with: .milli)))
          )
        @unknown default:
          break
        }
      }

      healthKitStore.execute(query)
    }

    let (offsets, lead1) = try await stream.reduce(into: ([Int](), [Double?]())) { accumulator, value in
      let (offset, value) = value
      // seconds -> milliseconds
      accumulator.0.append(Int(offset * 1000))
      // millivolt
      accumulator.1.append(value)
    }

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
      deviceModel: ecg.device?.model
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
