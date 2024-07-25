import Foundation

public struct SleepPatch: Equatable, Encodable {
  public struct Sleep: Equatable, Encodable {
    public struct SleepStages: Equatable, Encodable {

      
      public var unspecifiedSleepSamples: [LocalQuantitySample] = []
      public var awakeSleepSamples: [LocalQuantitySample] = []
      public var deepSleepSamples: [LocalQuantitySample] = []
      public var lightSleepSamples: [LocalQuantitySample] = []
      public var remSleepSamples: [LocalQuantitySample] = []
      public var inBedSleepSamples: [LocalQuantitySample] = []
      public var unknownSleepSamples: [LocalQuantitySample] = []
      
      public init() {}
    }
    
    public var id: UUID?
    public var startDate: Date
    public var endDate: Date
    public var sourceBundle: String
    public var productType: String

    public var heartRateMaximum: Int? = nil
    public var heartRateMinimum: Int? = nil
    public var heartRateMean: Int? = nil
    public var hrvMeanSdnn: Double? = nil
    public var respiratoryRateMean: Double? = nil

    public var heartRate: [LocalQuantitySample] = []
    public var heartRateVariability: [LocalQuantitySample] = []
    public var respiratoryRate: [LocalQuantitySample] = []
    public var wristTemperature: [LocalQuantitySample] = []

    public var sleepStages: SleepStages = .init()

    public var sourceType: SourceType {
      return .infer(sourceBundle: sourceBundle, productType: productType)
    }
    
    public init(
      id: UUID? = nil,
      startDate: Date,
      endDate: Date,
      sourceBundle: String,
      productType: String,
      heartRateMaximum: Int? = nil,
      heartRateMinimum: Int? = nil,
      heartRateMean: Int? = nil,
      hrvMeanSdnn: Double? = nil,
      respiratoryRateMean: Double? = nil,
      heartRate: [LocalQuantitySample] = [],
      heartRateVariability: [LocalQuantitySample] = [],
      respiratoryRate: [LocalQuantitySample] = [],
      sleepStages: SleepStages = .init()
    ) {
      self.id = id
      self.startDate = startDate
      self.endDate = endDate
      self.sourceBundle = sourceBundle
      self.productType = productType
      self.heartRateMaximum = heartRateMaximum
      self.heartRateMinimum = heartRateMinimum
      self.heartRateMean = heartRateMean
      self.hrvMeanSdnn = hrvMeanSdnn
      self.respiratoryRateMean = respiratoryRateMean
      self.heartRate = heartRate
      self.heartRateVariability = heartRateVariability
      self.respiratoryRate = respiratoryRate
      self.sleepStages = sleepStages
    }
  }
  
  public let sleep: [Sleep]
  
  public init(sleep: [Sleep]) {
    self.sleep = sleep
  }
}
