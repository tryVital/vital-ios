import Foundation

public struct WorkoutPatch: Encodable {
  public struct Workout: Encodable {
    public let id: UUID?
    public let startDate: Date
    public let endDate: Date
    public let sourceBundle: String
    public let productType: String?
    public let sport: String
    public let calories: Double
    public let distance: Double
    
    public var heartRate: [QuantitySample] = []
    public var respiratoryRate: [QuantitySample] = []
    
    public init(
      id: UUID? = nil,
      startDate: Date,
      endDate: Date,
      sourceBundle: String,
      productType: String?,
      sport: String,
      calories: Double,
      distance: Double,
      heartRate: [QuantitySample] = [],
      respiratoryRate: [QuantitySample] = []
    ) {
      self.id = id
      self.startDate = startDate
      self.endDate = endDate
      self.sourceBundle = sourceBundle
      self.productType = productType
      self.sport = sport
      self.calories = calories
      self.distance = distance
      self.heartRate = heartRate
      self.respiratoryRate = respiratoryRate
    }
  }
  
  public let workouts: [Workout]
  
  public init(workouts: [WorkoutPatch.Workout]) {
    self.workouts = workouts
  }
}
