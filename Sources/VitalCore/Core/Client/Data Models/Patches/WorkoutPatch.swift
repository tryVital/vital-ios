import Foundation

public struct WorkoutPatch: Equatable, Encodable {
  public struct Workout: Equatable, Encodable {
    public let id: UUID?
    public let startDate: Date
    public let endDate: Date
    public let movingTime: Double

    public let sourceBundle: String
    public let productType: String?
    public let sport: String
    public let calories: Double
    public let distance: Double
    public let ascentElevation: Double?
    public let descentElevation: Double?

    public var heartRate: [LocalQuantitySample] = []
    public var respiratoryRate: [LocalQuantitySample] = []

    public var sourceType: SourceType {
      return .infer(sourceBundle: sourceBundle, productType: productType)
    }

    public init(
      id: UUID? = nil,
      startDate: Date,
      endDate: Date,
      movingTime: Double,
      sourceBundle: String,
      productType: String?,
      sport: String,
      calories: Double,
      distance: Double,
      ascentElevation: Double?,
      descentElevation: Double?,
      heartRate: [LocalQuantitySample] = [],
      respiratoryRate: [LocalQuantitySample] = []
    ) {
      self.id = id
      self.startDate = startDate
      self.endDate = endDate
      self.movingTime = movingTime
      self.sourceBundle = sourceBundle
      self.productType = productType
      self.sport = sport
      self.calories = calories
      self.distance = distance
      self.ascentElevation = ascentElevation
      self.descentElevation = descentElevation
      self.heartRate = heartRate
      self.respiratoryRate = respiratoryRate
    }
  }
  
  public let workouts: [Workout]
  
  public init(workouts: [WorkoutPatch.Workout]) {
    self.workouts = workouts
  }
}
