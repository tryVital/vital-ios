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
    
    public var heartRate: [LocalQuantitySample] = []
    public var restingHeartRate: [LocalQuantitySample] = []
    public var heartRateVariability: [LocalQuantitySample] = []
    public var oxygenSaturation: [LocalQuantitySample] = []
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
      heartRate: [LocalQuantitySample] = [],
      restingHeartRate: [LocalQuantitySample] = [],
      heartRateVariability: [LocalQuantitySample] = [],
      oxygenSaturation: [LocalQuantitySample] = [],
      respiratoryRate: [LocalQuantitySample] = [],
      sleepStages: SleepStages = .init()
    ) {
      self.id = id
      self.startDate = startDate
      self.endDate = endDate
      self.sourceBundle = sourceBundle
      self.productType = productType
      self.heartRate = heartRate
      self.restingHeartRate = restingHeartRate
      self.heartRateVariability = heartRateVariability
      self.oxygenSaturation = oxygenSaturation
      self.respiratoryRate = respiratoryRate
      self.sleepStages = sleepStages
    }
  }
  
  public let sleep: [Sleep]
  
  public init(sleep: [Sleep]) {
    self.sleep = sleep
  }
}
