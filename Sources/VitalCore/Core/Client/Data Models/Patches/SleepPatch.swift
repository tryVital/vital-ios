import Foundation

public struct SleepPatch: Equatable, Encodable {
  public struct Sleep: Equatable, Encodable {
    public struct SleepStages: Equatable, Encodable {
      public var unspecifiedSleepSamples: [QuantitySample] = []
      public var awakeSleepSamples: [QuantitySample] = []
      public var deepSleepSamples: [QuantitySample] = []
      public var lightSleepSamples: [QuantitySample] = []
      public var remSleepSamples: [QuantitySample] = []
      public var inBedSleepSamples: [QuantitySample] = []
      public var unknownSleepSamples: [QuantitySample] = []
    }
    
    public var id: UUID?
    public var startDate: Date
    public var endDate: Date
    public var sourceBundle: String
    public var productType: String
    
    public var heartRate: [QuantitySample] = []
    public var restingHeartRate: [QuantitySample] = []
    public var heartRateVariability: [QuantitySample] = []
    public var oxygenSaturation: [QuantitySample] = []
    public var respiratoryRate: [QuantitySample] = []
    public var sleepStages: SleepStages = .init()
    
    public init(
      id: UUID? = nil,
      startDate: Date,
      endDate: Date,
      sourceBundle: String,
      productType: String,
      heartRate: [QuantitySample] = [],
      restingHeartRate: [QuantitySample] = [],
      heartRateVariability: [QuantitySample] = [],
      oxygenSaturation: [QuantitySample] = [],
      respiratoryRate: [QuantitySample] = []
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
    }
  }
  
  public let sleep: [Sleep]
  
  public init(sleep: [Sleep]) {
    self.sleep = sleep
  }
}
