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
    public let calories: Double?
    public let distance: Double?
    public let ascentElevation: Double?
    public let descentElevation: Double?


    public var heartRateMaximum: Int? = nil
    public var heartRateMinimum: Int? = nil
    public var heartRateMean: Int? = nil
    public var heartRateZone1: Int? = nil
    public var heartRateZone2: Int? = nil
    public var heartRateZone3: Int? = nil
    public var heartRateZone4: Int? = nil
    public var heartRateZone5: Int? = nil
    public var heartRateZone6: Int? = nil

    public var heartRate: [LocalQuantitySample] = []
    public var respiratoryRate: [LocalQuantitySample] = []

    public var stream: ManualWorkoutStream? = nil
    
    public var metadata: [String: String] = [:]

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
      calories: Double?,
      distance: Double?,
      heartRateMaximum: Int? = nil,
      heartRateMinimum: Int? = nil,
      heartRateMean: Int? = nil,
      heartRateZone1: Int? = nil,
      heartRateZone2: Int? = nil,
      heartRateZone3: Int? = nil,
      heartRateZone4: Int? = nil,
      heartRateZone5: Int? = nil,
      heartRateZone6: Int? = nil,
      ascentElevation: Double? = nil,
      descentElevation: Double? = nil,
      heartRate: [LocalQuantitySample] = [],
      respiratoryRate: [LocalQuantitySample] = [],
      metadata: [String: String] = [:]
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
      self.heartRateMaximum = heartRateMaximum
      self.heartRateMinimum = heartRateMinimum
      self.heartRateMean = heartRateMean
      self.heartRateZone1 = heartRateZone1
      self.heartRateZone2 = heartRateZone2
      self.heartRateZone3 = heartRateZone3
      self.heartRateZone4 = heartRateZone4
      self.heartRateZone5 = heartRateZone5
      self.heartRateZone6 = heartRateZone6
      self.ascentElevation = ascentElevation
      self.descentElevation = descentElevation
      self.heartRate = heartRate
      self.respiratoryRate = respiratoryRate
      self.metadata = metadata
    }
  }
  
  public let workouts: [Workout]
  
  public init(workouts: [WorkoutPatch.Workout]) {
    self.workouts = workouts
  }
}

public struct ManualWorkoutStream: Hashable, Encodable {
  public let components: [Component: [BulkQuantitySample]]

  public init(components: [Component : [BulkQuantitySample]]) {
    self.components = components
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(
      Dictionary(uniqueKeysWithValues: components.map { ($0.key.rawValue, $0.value) }),
      forKey: .components
    )
  }

  public enum CodingKeys: String, CodingKey {
    case components
  }
}

extension ManualWorkoutStream {
  public enum Component: String, Hashable, Codable {
    case distanceCycling = "distance_cycling"
    case distanceWalkingRunning = "distance_walking_running"
    case distanceRowing = "distance_rowing"
    case distanceWheelchair = "distance_wheelchair"
    case distanceDownhillSnowSports = "distance_downhill_snow_sports"
    case distanceSwimming = "distance_swimming"
    case distancePaddleSports = "distance_paddle_sports"
    case distanceSkatingSports = "distance_skating_sports"
    case distanceCrossCountrySkiing = "distance_cross_country_skiing"
    case swimmingStrokeCount = "swimming_stroke_count"
  }
}
