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
    _ correlation: HKCorrelation,
    unit: QuantityUnit
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
      correlation.objects.count == 2,
      let diastolic = correlation.objects.first(where: testType(.bloodPressureDiastolic)) as! HKQuantitySample?,
      let systolic = correlation.objects.first(where: testType(.bloodPressureSystolic)) as! HKQuantitySample?
    else {
      return nil
    }
        
    self.init(
      systolic: LocalQuantitySample(systolic, unit: unit),
      diastolic: LocalQuantitySample(diastolic, unit: unit),
      pulse: nil
    )
  }
}

extension LocalQuantitySample {
  init(
    _ sample: HKQuantitySample,
    unit: QuantityUnit
  ) {

    var doubleValue = sample.quantity.doubleValue(for: unit.healthKitRepresentation)

    if unit.vitalRepresentation == .percentage {
      // Vital uses [0, 100[ instead of [0, 1[, so we need to scale up the percentage.
      doubleValue = doubleValue * 100
    }

    var metadata: [String: String] = [:]

    if let metadataDict = sample.metadata {
      for (key, value) in metadataDict {
        if let stringValue = value as? String {
          metadata[key] = stringValue
        }
      }
    }

    self.init(
      value: doubleValue,
      startDate: sample.startDate,
      endDate: sample.endDate,
      sourceBundle: sample.sourceRevision.source.bundleIdentifier,
      productType: sample.sourceRevision.productType,
      type: nil,
      unit: unit.vitalRepresentation,
      metadata: metadata
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
  init(
    _ statistics: VitalStatistics,
    unit: QuantityUnit
  ) {

    self.init(
      value: statistics.value,
      startDate: statistics.startDate,
      endDate: statistics.endDate,
      sourceBundle: nil,
      productType: nil,
      type: .multipleSources,
      unit: unit.vitalRepresentation
    )
  }
}

struct QuantityUnit {
  let healthKitRepresentation: HKUnit
  let vitalRepresentation: LocalQuantitySample.Unit

  init(_ id: HKQuantityTypeIdentifier) {
    healthKitRepresentation = Self.vitalStandardUnits[id]!
    vitalRepresentation = Self.unitStringRepresentation[id]!
  }

  static let unitStringRepresentation: [HKQuantityTypeIdentifier: LocalQuantitySample.Unit] = {
    var mapping = [HKQuantityTypeIdentifier: LocalQuantitySample.Unit]()

    if #available(iOS 16.0, *) {
      mapping[.appleSleepingWristTemperature] = .degreeCelsius
    }

    mapping[.bodyMass] = .kg
    mapping[.bodyFatPercentage] = .percentage
    mapping[.height] = .centimeter
    mapping[.heartRate] = .bpm
    mapping[.respiratoryRate] = .bpm
    mapping[.heartRateVariabilitySDNN] = .rmssd
    mapping[.oxygenSaturation] = .percentage
    mapping[.restingHeartRate] = .bpm
    mapping[.activeEnergyBurned] = .kcal
    mapping[.basalEnergyBurned] = .kcal
    mapping[.stepCount] = .count
    mapping[.flightsClimbed] = .count
    mapping[.distanceWalkingRunning] = .meter
    mapping[.vo2Max] = .vo2Max
    mapping[.bloodGlucose] = .glucose
    mapping[.bloodPressureSystolic] = .mmHg
    mapping[.bloodPressureDiastolic] = .mmHg
    mapping[.dietaryWater] = .mL
    mapping[.dietaryCaffeine] = .gram
    mapping[.appleExerciseTime] = .minute
    mapping[.bodyTemperature] = .degreeCelsius
    mapping[.basalBodyTemperature] = .degreeCelsius
    mapping[.dietaryEnergyConsumed] = .kcal
    mapping[.dietaryBiotin] = .ug
    mapping[.dietaryCarbohydrates] = .gram
    mapping[.dietaryFiber] = .gram
    mapping[.dietarySugar] = .gram
    mapping[.dietaryFatTotal] = .gram
    mapping[.dietaryFatMonounsaturated] = .gram
    mapping[.dietaryFatPolyunsaturated] = .gram
    mapping[.dietaryFatSaturated] = .gram
    mapping[.dietaryCholesterol] = .mg
    mapping[.dietaryProtein] = .gram
    mapping[.dietaryVitaminA] = .ug
    mapping[.dietaryThiamin] = .mg
    mapping[.dietaryRiboflavin] = .mg
    mapping[.dietaryNiacin] = .mg
    mapping[.dietaryPantothenicAcid] = .mg
    mapping[.dietaryVitaminB6] = .mg
    mapping[.dietaryVitaminB12] = .ug
    mapping[.dietaryVitaminC] = .mg
    mapping[.dietaryVitaminD] = .ug
    mapping[.dietaryVitaminE] = .mg
    mapping[.dietaryVitaminK] = .ug
    mapping[.dietaryFolate] = .ug
    mapping[.dietaryCalcium] = .mg
    mapping[.dietaryChloride] = .mg
    mapping[.dietaryIron] = .mg
    mapping[.dietaryMagnesium] = .mg
    mapping[.dietaryPhosphorus] = .mg
    mapping[.dietaryPotassium] = .mg
    mapping[.dietarySodium] = .mg
    mapping[.dietaryZinc] = .mg
    mapping[.dietaryChromium] = .ug
    mapping[.dietaryCopper] = .mg
    mapping[.dietaryIodine] = .ug
    mapping[.dietaryManganese] = .mg
    mapping[.dietaryMolybdenum] = .ug
    mapping[.dietarySelenium] = .ug
    mapping[.dietaryWater] = .mL
    mapping[.dietaryCaffeine] = .mg

    return mapping
  }()
  
  static let vitalStandardUnits: [HKQuantityTypeIdentifier: HKUnit] = {
    var mapping = [HKQuantityTypeIdentifier: HKUnit]()

    if #available(iOS 16.0, *) {
      mapping[.appleSleepingWristTemperature] = .degreeCelsius()
    }

    mapping[.bodyMass] = .gramUnit(with: .kilo)
    mapping[.bodyFatPercentage] = .percent()
    mapping[.height] = .meterUnit(with: .centi)
    mapping[.heartRate] = .count().unitDivided(by: .minute())
    mapping[.respiratoryRate] = .count().unitDivided(by: .minute())
    mapping[.heartRateVariabilitySDNN] = .secondUnit(with: .milli)
    mapping[.oxygenSaturation] = .percent()
    mapping[.restingHeartRate] = .count().unitDivided(by: .minute())
    mapping[.activeEnergyBurned] = .kilocalorie()
    mapping[.basalEnergyBurned] = .kilocalorie()
    mapping[.stepCount] = .count()
    mapping[.flightsClimbed] = .count()
    mapping[.distanceWalkingRunning] = .meter()
    mapping[.vo2Max] = .literUnit(with: .milli).unitDivided(by: .gramUnit(with: .kilo).unitMultiplied(by: .minute()))
    mapping[.bloodGlucose] = .moleUnit(with: .milli, molarMass: HKUnitMolarMassBloodGlucose).unitDivided(by: .liter())
    mapping[.bloodPressureSystolic] = .millimeterOfMercury()
    mapping[.bloodPressureDiastolic] = .millimeterOfMercury()
    mapping[.dietaryWater] = .literUnit(with: .milli)
    mapping[.dietaryCaffeine] = .gram()
    mapping[.appleExerciseTime] = .minute()
    mapping[.bodyTemperature] = .degreeCelsius()
    mapping[.basalBodyTemperature] = .degreeCelsius()
    mapping[.dietaryEnergyConsumed] = .kilocalorie()
    mapping[.dietaryBiotin] = .gramUnit(with: .micro)
    mapping[.dietaryCarbohydrates] = .gram()
    mapping[.dietaryFiber] = .gram()
    mapping[.dietarySugar] = .gram()
    mapping[.dietaryFatTotal] = .gram()
    mapping[.dietaryFatMonounsaturated] = .gram()
    mapping[.dietaryFatPolyunsaturated] = .gram()
    mapping[.dietaryFatSaturated] = .gram()
    mapping[.dietaryCholesterol] = .gramUnit(with: .milli)
    mapping[.dietaryProtein] = .gram()
    mapping[.dietaryVitaminA] = .gramUnit(with: .micro)
    mapping[.dietaryThiamin] = .gramUnit(with: .milli)
    mapping[.dietaryRiboflavin] = .gramUnit(with: .milli)
    mapping[.dietaryNiacin] = .gramUnit(with: .milli)
    mapping[.dietaryPantothenicAcid] = .gramUnit(with: .milli)
    mapping[.dietaryVitaminB6] = .gramUnit(with: .milli)
    mapping[.dietaryVitaminB12] = .gramUnit(with: .micro)
    mapping[.dietaryVitaminC] = .gramUnit(with: .milli)
    mapping[.dietaryVitaminD] = .gramUnit(with: .micro)
    mapping[.dietaryVitaminE] = .gramUnit(with: .milli)
    mapping[.dietaryVitaminK] = .gramUnit(with: .micro)
    mapping[.dietaryFolate] = .gramUnit(with: .micro)
    mapping[.dietaryCalcium] = .gramUnit(with: .milli)
    mapping[.dietaryChloride] = .gramUnit(with: .milli)
    mapping[.dietaryIron] = .gramUnit(with: .milli)
    mapping[.dietaryMagnesium] = .gramUnit(with: .milli)
    mapping[.dietaryPhosphorus] = .gramUnit(with: .milli)
    mapping[.dietaryPotassium] = .gramUnit(with: .milli)
    mapping[.dietarySodium] = .gramUnit(with: .milli)
    mapping[.dietaryZinc] = .gramUnit(with: .milli)
    mapping[.dietaryChromium] = .gramUnit(with: .micro)
    mapping[.dietaryCopper] = .gramUnit(with: .milli)
    mapping[.dietaryIodine] = .gramUnit(with: .micro)
    mapping[.dietaryManganese] = .gramUnit(with: .milli)
    mapping[.dietaryMolybdenum] = .gramUnit(with: .micro)
    mapping[.dietarySelenium] = .gramUnit(with: .micro)
    mapping[.dietaryWater] = .literUnit(with: .milli)
    mapping[.dietaryCaffeine] = .gramUnit(with: .milli)

    return mapping
  }()
}

extension HKQuantityType {

  var idealStatisticalQueryOptions: HKStatisticsOptions {

    switch aggregationStyle {
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

    switch aggregationStyle {
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
}

extension HKSampleType {

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
      value: Double(categorySample.value),
      startDate: categorySample.startDate,
      endDate: categorySample.endDate,
      sourceBundle: categorySample.sourceRevision.source.bundleIdentifier,
      productType: categorySample.sourceRevision.productType,
      type: nil,
      unit: .stage
    )
  }
}

extension LocalQuantitySample {
  static func fromMindfulSession(sample: HKCategorySample) -> LocalQuantitySample? {

    guard let minutes = Date.differenceInMinutes(startDate: sample.startDate, endDate: sample.endDate) else {
      return nil
    }

    return self.init(
      value: Double(minutes),
      startDate: sample.startDate,
      endDate: sample.endDate,
      sourceBundle: sample.sourceRevision.source.bundleIdentifier,
      productType: sample.sourceRevision.productType,
      type: nil,
      unit: .minute
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
