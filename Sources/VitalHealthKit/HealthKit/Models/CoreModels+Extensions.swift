import HealthKit
import VitalCore

extension ActivityPatch.Activity {
  init(sampleType: HKSampleType, date: Date, samples: [LocalQuantitySample]) {
    switch sampleType {
      case .quantityType(forIdentifier: .activeEnergyBurned)!:
        self.init(activeEnergyBurned: samples)
        
      case .quantityType(forIdentifier: .basalEnergyBurned)!:
        self.init(basalEnergyBurned: samples)
        
      case .quantityType(forIdentifier: .stepCount)!:
        self.init(steps: samples)
        
      case .quantityType(forIdentifier: .flightsClimbed)!:
        self.init(floorsClimbed: samples)
        
      case .quantityType(forIdentifier: .distanceWalkingRunning)!:
        self.init(distanceWalkingRunning: samples)
        
      case .quantityType(forIdentifier: .vo2Max)!:
        self.init(vo2Max: samples)
        
      default:
        fatalError("\(String(describing: sampleType)) cannot be used when constructing an ActivityPatch.Activity")
    }
  }
}

extension ActivityPatch {
  init(sampleType: HKSampleType, samples: [LocalQuantitySample]) {
    
    let allDates: Set<Date> = Set(samples.reduce([]) { acc, next in
      acc + [next.startDate.dayStart]
    })
    
    let activities = allDates.map { date -> ActivityPatch.Activity in
      func filter(_ samples: [LocalQuantitySample]) -> [LocalQuantitySample] {
        samples.filter { $0.startDate.dayStart == date }
      }
      
      let filteredSamples = filter(samples)
      return ActivityPatch.Activity(sampleType: sampleType, date: date, samples: filteredSamples)
    }
    
    self.init(activities: activities)
  }
}

extension BodyPatch {
  init(sampleType: HKSampleType, samples: [LocalQuantitySample]) {
    switch sampleType {
      case .quantityType(forIdentifier: .bodyMass)!:
        self.init(bodyMass: samples)
        
      case .quantityType(forIdentifier: .bodyFatPercentage)!:
        self.init(bodyFatPercentage: samples)
        
      default:
        fatalError("\(String(describing: sampleType)) cannot be used when constructing an BodyPatch")
    }
  }
}

extension HKSampleType {
  
  var toIndividualResource: VitalResource {
    switch self {
      case HKQuantityType.quantityType(forIdentifier: .bodyMass)!:
        return .individual(.weight)
      
      case HKQuantityType.quantityType(forIdentifier: .bodyFatPercentage)!:
        return .individual(.bodyFat)
      
      case HKSampleType.quantityType(forIdentifier: .activeEnergyBurned)!:
        return .individual(.activeEnergyBurned)
        
      case HKSampleType.quantityType(forIdentifier: .basalEnergyBurned)!:
        return .individual(.basalEnergyBurned)
        
      case HKSampleType.quantityType(forIdentifier: .stepCount)!:
        return .individual(.steps)
        
      case HKSampleType.quantityType(forIdentifier: .flightsClimbed)!:
        return .individual(.floorsClimbed)
        
      case HKSampleType.quantityType(forIdentifier: .distanceWalkingRunning)!:
        return .individual(.distanceWalkingRunning)

      case HKSampleType.quantityType(forIdentifier: .vo2Max)!:
        return .individual(.vo2Max)

      case HKSampleType.quantityType(forIdentifier: .appleExerciseTime)!:
        return .individual(.exerciseTime)
        
      default:
        fatalError("\(String(describing: self)) is not supported. This is a developer error")
    }
  }
}

extension LocalBloodPressureSample {
  init?(
    _ sample: HKSample
  ) {
    
    func testType(_ identifier: HKQuantityTypeIdentifier) -> (HKSample) -> Bool {
      return { sample in
        guard
          let value = sample as? HKQuantitySample,
          value.quantityType == HKQuantityType.quantityType(forIdentifier: identifier)
        else {
          return false
        }
        
        return true
      }
    }
    
    guard
      let correlation = sample as? HKCorrelation,
      correlation.objects.count == 2,
      let diastolic = correlation.objects.first(where: testType(.bloodPressureDiastolic)),
      let systolic = correlation.objects.first(where: testType(.bloodPressureSystolic)),
      let diastolicSample = LocalQuantitySample(diastolic),
      let systolicSample = LocalQuantitySample(systolic)
    else {
      return nil
    }
        
    self.init(
      systolic: systolicSample,
      diastolic: diastolicSample,
      pulse: nil
    )
  }
}

extension LocalQuantitySample {
  init?(
    _ sample: HKSample
  ) {
    guard let value = sample as? HKQuantitySample else {
      return nil
    }

    let unit = sample.sampleType.toHealthKitUnits
    var doubleValue = value.quantity.doubleValue(for: unit)

    if unit == HKUnit.percent() {
      // Vital uses [0, 100[ instead of [0, 1[, so we need to scale up the percentage.
      doubleValue = doubleValue * 100
    }

    self.init(
      id: value.uuid.uuidString,
      value: doubleValue,
      startDate: sample.startDate,
      endDate: sample.endDate,
      sourceBundle: value.sourceRevision.source.bundleIdentifier,
      productType: value.sourceRevision.productType,
      type: nil,
      unit: sample.sampleType.toUnitStringRepresentation
    )
  }
}

func isValidStatistic(_ statistics: VitalStatistics) -> Bool {
  return statistics.value > 0
}

func generateIdForAnchor(_ statistics: VitalStatistics) -> String? {
  let id = "\(statistics.startDate)-\(statistics.endDate)-\(statistics.type)-\(statistics.value)"
  return id.sha256()
}

private func generateIdForServer(for startDate: Date, endDate: Date, type: String) -> String? {
  let id = "\(startDate)-\(endDate)-\(type)"
  return id.sha256()
}

extension LocalQuantitySample {
  init?(
    _ statistics: VitalStatistics,
    _ sampleType: HKQuantityType
  ) {
    
    let type = String(describing: sampleType)

    guard
      let idString = generateIdForServer(for: statistics.startDate, endDate: statistics.endDate, type: type)
    else {
      return nil
    }

    self.init(
      id: idString,
      value: statistics.value,
      startDate: statistics.startDate,
      endDate: statistics.endDate,
      sourceBundle: nil,
      productType: nil,
      type: .multipleSources,
      unit: sampleType.toUnitStringRepresentation,
      metadata: nil
    )
  }
}

extension HKSampleType {
  var toUnitStringRepresentation: String {
    if #available(iOS 16.0, *) {
      switch self {
        case HKQuantityType.quantityType(forIdentifier: .appleSleepingWristTemperature)!:
          return "C"
        default:
          break
      }
    }

    switch self {
      case HKQuantityType.quantityType(forIdentifier: .bodyMass)!:
        return "kg"
      case HKQuantityType.quantityType(forIdentifier: .bodyFatPercentage)!:
        return "percent"
        
      case HKQuantityType.quantityType(forIdentifier: .height)!:
        return "cm"
        
      case HKSampleType.quantityType(forIdentifier: .heartRate)!:
        return "bpm"
      case HKSampleType.quantityType(forIdentifier: .respiratoryRate)!:
        //  "breaths per minute"
        return "bpm"
        
      case HKSampleType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!:
        return "rmssd"
      case HKSampleType.quantityType(forIdentifier: .oxygenSaturation)!:
        return "percent"
      case HKSampleType.quantityType(forIdentifier: .restingHeartRate)!:
        return "bpm"
      
      case
        HKSampleType.quantityType(forIdentifier: .activeEnergyBurned)!,
        HKSampleType.quantityType(forIdentifier: .basalEnergyBurned)!:
        return "kcal"
        
      case HKSampleType.quantityType(forIdentifier: .stepCount)!:
        return ""
      case HKSampleType.quantityType(forIdentifier: .flightsClimbed)!:
        return ""
      case HKSampleType.quantityType(forIdentifier: .distanceWalkingRunning)!:
        return "m"
      case  HKSampleType.quantityType(forIdentifier: .vo2Max)!:
        return "mL/kg/min"
        
      case HKSampleType.quantityType(forIdentifier: .bloodGlucose)!:
        return "mmol/L"
        
      case
        HKSampleType.quantityType(forIdentifier: .bloodPressureSystolic)!,
        HKSampleType.quantityType(forIdentifier: .bloodPressureDiastolic)!:
        return "mmHg"
        
      case HKQuantityType.quantityType(forIdentifier: .dietaryWater)!:
        return "mL"

      case HKQuantityType.quantityType(forIdentifier: .dietaryCaffeine)!:
        return "g"

      case HKQuantityType.quantityType(forIdentifier: .appleExerciseTime)!:
        return "min"

    case
      HKSampleType.quantityType(forIdentifier: .bodyTemperature)!,
      HKSampleType.quantityType(forIdentifier: .basalBodyTemperature)!:
      return "\u{00B0}C"

      default:
        fatalError("\(String(describing: self)) type not supported)")
    }
  }
  
  var toHealthKitUnits: HKUnit {

    if #available(iOS 16.0, *) {
      switch self {
        case HKSampleType.quantityType(forIdentifier: .appleSleepingWristTemperature)!:
          return .degreeCelsius()
        default:
          break
      }
    }

    switch self {
      case HKQuantityType.quantityType(forIdentifier: .bodyMass)!:
        return .gramUnit(with: .kilo)
      case HKQuantityType.quantityType(forIdentifier: .bodyFatPercentage)!:
        return .percent()
        
      case HKQuantityType.quantityType(forIdentifier: .height)!:
        return .meterUnit(with: .centi)
        
      case HKSampleType.quantityType(forIdentifier: .heartRate)!:
        return .count().unitDivided(by: .minute())
      case HKSampleType.quantityType(forIdentifier: .respiratoryRate)!:
        //  "breaths per minute"
        return .count().unitDivided(by: .minute())
        
      case HKSampleType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!:
        return .secondUnit(with: .milli)
      case HKSampleType.quantityType(forIdentifier: .oxygenSaturation)!:
        return .percent()
      case HKSampleType.quantityType(forIdentifier: .restingHeartRate)!:
        return .count().unitDivided(by: .minute())
        
      case
        HKSampleType.quantityType(forIdentifier: .activeEnergyBurned)!,
        HKSampleType.quantityType(forIdentifier: .basalEnergyBurned)!:
        return .kilocalorie()
        
      case HKSampleType.quantityType(forIdentifier: .stepCount)!:
        return .count()
      case HKSampleType.quantityType(forIdentifier: .flightsClimbed)!:
        return .count()
      case HKSampleType.quantityType(forIdentifier: .distanceWalkingRunning)!:
        return .meter()
      case  HKSampleType.quantityType(forIdentifier: .vo2Max)!:
        return .literUnit(with: .milli).unitDivided(by: .gramUnit(with: .kilo).unitMultiplied(by: .minute()))
        
      case HKSampleType.quantityType(forIdentifier: .bloodGlucose)!:
        return .moleUnit(with: .milli, molarMass: HKUnitMolarMassBloodGlucose).unitDivided(by: .liter())
        
      case HKSampleType.quantityType(forIdentifier: .dietaryWater)!:
        return .literUnit(with: .milli)

      case HKSampleType.quantityType(forIdentifier: .dietaryCaffeine)!:
        return .gram()

      case
        HKSampleType.quantityType(forIdentifier: .bloodPressureSystolic)!,
        HKSampleType.quantityType(forIdentifier: .bloodPressureDiastolic)!:
        return .millimeterOfMercury()
        
      case
        HKSampleType.quantityType(forIdentifier: .appleExerciseTime)!:
        return .minute()

    case
      HKSampleType.quantityType(forIdentifier: .bodyTemperature)!,
      HKSampleType.quantityType(forIdentifier: .basalBodyTemperature)!:
      return .degreeCelsius()

      default:
        fatalError("\(String(describing: self)) type not supported)")
    }
  }

  var idealStatisticalQueryOptions: HKStatisticsOptions {
    guard let quantityType = self as? HKQuantityType else {
      fatalError("Only quantity types can work with HKStatisticalQuery.")
    }

    switch quantityType.aggregationStyle {
    case .cumulative:
      // We always want sum for cumulative quantity types.
      return [.cumulativeSum]

    case .discreteArithmetic:
      // Defaults to most recent reading.
      return [.mostRecent]

    case .discreteTemporallyWeighted, .discreteEquivalentContinuousLevel:
      // Not supported.
      return []

    @unknown default:
      return []
    }
  }

  func idealStatisticalQuantity(from statistics: HKStatistics) -> HKQuantity? {
    guard let quantityType = self as? HKQuantityType else {
      fatalError("Only quantity types can work with HKStatisticalQuery.")
    }

    switch quantityType.aggregationStyle {
    case .cumulative:
      // We always want sum for cumulative quantity types.
      return statistics.sumQuantity()

    case .discreteArithmetic:
      // Defaults to most recent reading.
      return statistics.mostRecentQuantity()

    case .discreteTemporallyWeighted, .discreteEquivalentContinuousLevel:
      // Not supported.
      return nil

    @unknown default:
      return nil
    }
  }

  var shortenedIdentifier: String {
    if self is HKQuantityType {
      return String(self.identifier.dropFirst("HKQuantityTypeIdentifier".count))
    }

    if self is HKCorrelationType {
      return String(self.identifier.dropFirst("HKCorrelationTypeIdentifier".count))
    }

    if self is HKCategoryType {
      return String(self.identifier.dropFirst("HKCategoryTypeIdentifier".count))
    }

    return self.identifier
  }
}

func quantity(for statistics: HKStatistics, with options: HKStatisticsOptions?, type: HKQuantityType) -> HKQuantity? {

  guard let options = options else {
    return type.idealStatisticalQuantity(from: statistics)
  }

  switch options {
    case .discreteMax:
      return statistics.maximumQuantity()
    case .discreteAverage:
      return statistics.averageQuantity()
    case .discreteMin:
      return statistics.minimumQuantity()
    default:
      return type.idealStatisticalQuantity(from: statistics)
  }
}

extension ProfilePatch.BiologicalSex {
  init(healthKitSex: HKBiologicalSex) {
    switch healthKitSex {
      case .notSet:
        self = .notSet
      case .female:
        self = .female
      case .male:
        self = .male
      case .other:
        self = .other
      @unknown default:
        self = .other
    }
  }
}

public extension SleepPatch.Sleep {
  init?(sample: HKSample) {
    guard
      let value = sample as? HKCategorySample,
      let productType = value.sourceRevision.productType
    else {
      return nil
    }
    
    self.init(
      id: value.uuid,
      startDate: sample.startDate,
      endDate: sample.endDate,
      sourceBundle: value.sourceRevision.source.bundleIdentifier,
      productType: productType
    )
  }
}

extension WorkoutPatch.Workout {
  public init(_ workout: HKWorkout) {
    var ascentElevation: Double? = nil
    if let ascentElevationQuantity = workout.metadata?[HKMetadataKeyElevationAscended] as? HKQuantity {
      ascentElevation = ascentElevationQuantity.doubleValue(for: .meter())
    }

    var descentElevation: Double? = nil
    if let descentElevationQuantity = workout.metadata?[HKMetadataKeyElevationDescended] as? HKQuantity {
      descentElevation = descentElevationQuantity.doubleValue(for: .meter())
    }

    self.init(
      id: workout.uuid,
      startDate: workout.startDate,
      endDate: workout.endDate,
      movingTime: workout.duration,
      sourceBundle: workout.sourceRevision.source.bundleIdentifier,
      productType: workout.sourceRevision.productType,
      sport: workout.workoutActivityType.toString,
      calories: workout.totalEnergyBurned?.doubleValue(for: .kilocalorie()) ?? 0,
      distance: workout.totalDistance?.doubleValue(for: .meter()) ?? 0, 
      ascentElevation: ascentElevation,
      descentElevation: descentElevation
    )
  }
}

extension LocalQuantitySample {
  public init(categorySample: HKCategorySample) {
    self.init(
      id: categorySample.uuid.uuidString,
      value: Double(categorySample.value),
      startDate: categorySample.startDate,
      endDate: categorySample.endDate,
      sourceBundle: categorySample.sourceRevision.source.bundleIdentifier,
      productType: categorySample.sourceRevision.productType,
      type: nil,
      unit: "stage"
    )
  }
}

extension LocalQuantitySample {
  static func fromMindfulSession(sample: HKSample) -> LocalQuantitySample? {

    guard let minutes = Date.differenceInMinutes(startDate: sample.startDate, endDate: sample.endDate) else {
      return nil
    }

    return self.init(
      id: sample.uuid.uuidString,
      value: Double(minutes),
      startDate: sample.startDate,
      endDate: sample.endDate,
      sourceBundle: sample.sourceRevision.source.bundleIdentifier,
      productType: sample.sourceRevision.productType,
      type: nil,
      unit: "minute"
    )
  }
}

extension ProfilePatch {
  var id: String? {
    let biologicalSex = String(describing: self.biologicalSex?.rawValue)
    let dateOfBirth = String(describing: self.dateOfBirth)
    let height = String(describing: self.height?.description)
    let timeZone = String(describing: self.timeZone)

    return "\(biologicalSex)_\(dateOfBirth)_\(height)_\(timeZone)".sha256()
  }
}
