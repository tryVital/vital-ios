import Foundation

public struct ActivityPatch: Equatable, Encodable {
  public struct Activity: Equatable, Encodable {
    public var activeEnergyBurned: [QuantitySample] = []
    public var basalEnergyBurned: [QuantitySample] = []
    public var steps: [QuantitySample] = []
    public var floorsClimbed: [QuantitySample] = []
    public var distanceWalkingRunning: [QuantitySample] = []
    public var vo2Max: [QuantitySample] = []
    
    public init(
      activeEnergyBurned: [QuantitySample] = [],
      basalEnergyBurned: [QuantitySample] = [],
      steps: [QuantitySample] = [],
      floorsClimbed: [QuantitySample] = [],
      distanceWalkingRunning: [QuantitySample] = [],
      vo2Max: [QuantitySample] = []
    ) {
      self.activeEnergyBurned = activeEnergyBurned
      self.basalEnergyBurned = basalEnergyBurned
      self.steps = steps
      self.floorsClimbed = floorsClimbed
      self.distanceWalkingRunning = distanceWalkingRunning
      self.vo2Max = vo2Max
    }
  }
  
  public let activities: [Activity]
  
  public init(activities: [Activity]) {
    self.activities = activities
  }
}
