import HealthKit

public struct ManualElectrocardiogram: Equatable, Encodable {
  public let electrocardiogram: ManualElectrocardiogram.Summary
  public let voltageData: ManualElectrocardiogram.VoltageData

  public init(electrocardiogram: ManualElectrocardiogram.Summary, voltageData: ManualElectrocardiogram.VoltageData) {
    self.electrocardiogram = electrocardiogram
    self.voltageData = voltageData
  }
}

extension ManualElectrocardiogram {
  public enum Classification: String, Codable {
    case sinusRhythm = "sinus_rhythm"
    case atrialFibrillation = "atrial_fibrillation"
    case inconclusive = "inconclusive"
  }

  public enum InconclusiveCause: String, Codable {
    case highHeartRate = "high_heart_rate"
    case lowHeartRate = "low_heart_rate"
    case poorReading = "poor_reading"
  }

  public struct Summary: Equatable, Encodable {
    public let id: String

    public let sessionStart: Date
    public let sessionEnd: Date

    public let voltageSampleCount: Int
    public let heartRateMean: Int?
    public let samplingFrequencyHz: Double?

    public let classification: Classification?
    public let inconclusiveCause: InconclusiveCause?

    public let algorithmVersion: String?

    public let sourceBundle: String
    public let productType: String?
    public let deviceModel: String?

    public let metadata: [String: String]?

    public init(
      id: String,
      sessionStart: Date,
      sessionEnd: Date,
      voltageSampleCount: Int,
      heartRateMean: Int?,
      samplingFrequencyHz: Double?,
      classification: Classification?,
      inconclusiveCause: InconclusiveCause?,
      algorithmVersion: String?,
      sourceBundle: String,
      productType: String?,
      deviceModel: String?,
      metadata: [String: String]? = nil
    ) {
      self.id = id
      self.sessionStart = sessionStart
      self.sessionEnd = sessionEnd
      self.voltageSampleCount = voltageSampleCount
      self.heartRateMean = heartRateMean
      self.samplingFrequencyHz = samplingFrequencyHz
      self.classification = classification
      self.inconclusiveCause = inconclusiveCause
      self.algorithmVersion = algorithmVersion
      self.sourceBundle = sourceBundle
      self.productType = productType
      self.deviceModel = deviceModel
      self.metadata = metadata
    }
  }

  public struct VoltageData: Equatable, Encodable {
    public let sessionStartOffsetMillisecond: [Int]
    public let lead1: [Double?]

    public init(sessionStartOffsetMillisecond: [Int], lead1: [Double?]) {
      self.sessionStartOffsetMillisecond = sessionStartOffsetMillisecond
      self.lead1 = lead1
    }
  }

  public static func mapClassification(_ ecgClassification: HKElectrocardiogram.Classification) -> (Classification?, InconclusiveCause?) {
    switch ecgClassification {
    case .atrialFibrillation:
      return (.atrialFibrillation, nil)
    case .sinusRhythm:
      return (.sinusRhythm, nil)
    case .inconclusiveHighHeartRate:
      return (.inconclusive, .highHeartRate)
    case .inconclusiveLowHeartRate:
      return (.inconclusive, .lowHeartRate)
    case .inconclusivePoorReading:
      return (.inconclusive, .poorReading)
    case .inconclusiveOther:
      return (.inconclusive, nil)
    case .notSet, .unrecognized:
      return (nil, nil)
    @unknown default:
      return (nil, nil)
    }
  }
}
