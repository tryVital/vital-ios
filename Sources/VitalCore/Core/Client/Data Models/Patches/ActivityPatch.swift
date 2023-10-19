import Foundation

public struct ActivityPatch: Equatable, Encodable {
  public struct Activity: Equatable, Encodable {
    public var daySummary: DaySummary? = nil
    public var activeEnergyBurned: [QuantitySample] = []
    public var basalEnergyBurned: [QuantitySample] = []
    public var steps: [QuantitySample] = []
    public var floorsClimbed: [QuantitySample] = []
    public var distanceWalkingRunning: [QuantitySample] = []
    public var vo2Max: [QuantitySample] = []

    public var isNotEmpty: Bool {
      (daySummary.map(\.isNotEmpty) ?? false) || !activeEnergyBurned.isEmpty ||
      !basalEnergyBurned.isEmpty || !basalEnergyBurned.isEmpty ||
      !steps.isEmpty || !floorsClimbed.isEmpty ||
      !distanceWalkingRunning.isEmpty || !vo2Max.isEmpty
    }

    public init(
      daySummary: DaySummary? = nil,
      activeEnergyBurned: [QuantitySample] = [],
      basalEnergyBurned: [QuantitySample] = [],
      steps: [QuantitySample] = [],
      floorsClimbed: [QuantitySample] = [],
      distanceWalkingRunning: [QuantitySample] = [],
      vo2Max: [QuantitySample] = []
    ) {
      self.daySummary = daySummary
      self.activeEnergyBurned = activeEnergyBurned
      self.basalEnergyBurned = basalEnergyBurned
      self.steps = steps
      self.floorsClimbed = floorsClimbed
      self.distanceWalkingRunning = distanceWalkingRunning
      self.vo2Max = vo2Max
    }
  }

  public struct DaySummary: Equatable, Encodable {
    public let calendarDate: GregorianCalendar.FloatingDate

    public var activeEnergyBurnedSum: Double?
    public var basalEnergyBurnedSum: Double?
    public var stepsSum: Int?
    public var floorsClimbedSum: Int?
    public var distanceWalkingRunningSum: Double?
    public var vo2Max: Double?

    public var low: Double?
    public var medium: Double?
    public var high: Double?

    public var maxHeartRate: Int?
    public var minHeartRate: Int?
    public var avgHeartRate: Int?
    public var restingHeartRate: Int?

    public var isNotEmpty: Bool {
      activeEnergyBurnedSum != nil || basalEnergyBurnedSum != nil ||
      stepsSum != nil || floorsClimbedSum != nil ||
      distanceWalkingRunningSum != nil || vo2Max != nil ||
      low != nil || medium != nil || high != nil || maxHeartRate != nil ||
      minHeartRate != nil || avgHeartRate != nil || restingHeartRate != nil
    }

    public init(
      calendarDate: GregorianCalendar.FloatingDate,
      activeEnergyBurnedSum: Double? = nil,
      basalEnergyBurnedSum: Double? = nil,
      stepsSum: Int? = nil,
      floorsClimbedSum: Int? = nil,
      distanceWalkingRunningSum: Double? = nil,
      vo2Max: Double? = nil,
      low: Double? = nil,
      medium: Double? = nil,
      high: Double? = nil,
      maxHeartRate: Int? = nil,
      minHeartRate: Int? = nil,
      avgHeartRate: Int? = nil,
      restingHeartRate: Int? = nil
    ) {
      self.calendarDate = calendarDate
      self.activeEnergyBurnedSum = activeEnergyBurnedSum
      self.basalEnergyBurnedSum = basalEnergyBurnedSum
      self.stepsSum = stepsSum
      self.floorsClimbedSum = floorsClimbedSum
      self.distanceWalkingRunningSum = distanceWalkingRunningSum
      self.vo2Max = vo2Max
      self.low = low
      self.medium = medium
      self.high = high
      self.maxHeartRate = maxHeartRate
      self.minHeartRate = minHeartRate
      self.avgHeartRate = avgHeartRate
      self.restingHeartRate = restingHeartRate
    }
  }
  
  public let activities: [Activity]

  public var isNotEmpty: Bool {
    activities.contains { $0.isNotEmpty }
  }
  
  public init(activities: [Activity]) {
    self.activities = activities
  }
}
