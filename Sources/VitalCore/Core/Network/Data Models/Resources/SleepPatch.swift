import Foundation

public struct SleepPatch: Encodable {
  public struct Sleep: Encodable {
    public let id: UUID?
    public let startDate: Date
    public let endDate: Date
    public let sourceBundle: String
    
    public var heartRate: [QuantitySample] = []
    public var restingHeartRate: [QuantitySample] = []
    public var heartRateVariability: [QuantitySample] = []
    public var oxygenSaturation: [QuantitySample] = []
    public var respiratoryRate: [QuantitySample] = []
    
    public init(
      id: UUID? = nil,
      startDate: Date,
      endDate: Date,
      sourceBundle: String,
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
