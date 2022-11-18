import HealthKit
import VitalCore

typealias SampleQueryHandler = (HKSampleQuery, [HKSample]?, Error?) -> Void
typealias AnchorQueryHandler = (HKAnchoredObjectQuery, [HKSample]?, [HKDeletedObject]?, HKQueryAnchor?, Error?) -> Void
typealias ActivityQueryHandler = (HKActivitySummaryQuery, [HKActivitySummary]?, Error?) -> Void

typealias SeriesSampleHandler = (HKQuantitySeriesSampleQuery, HKQuantity?, DateInterval?, HKQuantitySample?, Bool, Error?) -> Void

typealias StatisticsHandler = (HKStatisticsCollectionQuery, HKStatisticsCollection?, Error?) -> Void


private func read(
  type: HKSampleType,
  healthKitStore: HKHealthStore,
  vitalStorage: VitalHealthKitStorage?,
  typeToResource: ((HKSampleType) -> VitalResource),
  startDate: Date,
  endDate: Date
) async throws -> (ProcessedResourceData, [StoredAnchor]) {
  func queryQuantities(
    type: HKSampleType
  ) async throws -> (quantities: [QuantitySample], StoredAnchor?) {
    
    let payload = try await query(
      healthKitStore: healthKitStore,
      vitalStorage: vitalStorage,
      type: type,
      startDate: startDate,
      endDate: endDate
    )
    
    let quantities: [QuantitySample] = payload.sample.compactMap(QuantitySample.init)
    return (quantities, payload.anchor)
  }
  
  func queryStatistics(
    type: HKQuantityType
  ) async throws -> (quantities: [QuantitySample], StoredAnchor?) {
    
    let payload = try await queryStatisticsSample(
      healthKitStore: healthKitStore,
      vitalStorage: vitalStorage,
      type: type,
      startDate: startDate,
      endDate: endDate
    )
        
    let quantities: [QuantitySample] = payload.statistics.compactMap { value in
      return QuantitySample(value, type)
    }
            
    return (quantities, payload.anchor)
  }
  
  var anchors: [StoredAnchor] = []
  
  switch type {
    case
      /// Activity
      HKSampleType.quantityType(forIdentifier: .activeEnergyBurned)!,
      HKSampleType.quantityType(forIdentifier: .basalEnergyBurned)!,
      HKSampleType.quantityType(forIdentifier: .stepCount)!,
      HKSampleType.quantityType(forIdentifier: .flightsClimbed)!,
      HKSampleType.quantityType(forIdentifier: .distanceWalkingRunning)!:
      
      let (values, anchor) = try await queryStatistics(type: type as! HKQuantityType)
      let patch = ActivityPatch(sampleType: type, samples: values)
      
      anchors.appendOptional(anchor)
      
      return (ProcessedResourceData.summary(.activity(patch)), anchors)
      
    case
      /// Activity
      HKSampleType.quantityType(forIdentifier: .vo2Max)!:
      
      let (values, anchor) = try await queryQuantities(type: type)
      let patch = ActivityPatch(sampleType: type, samples: values)
      
      anchors.appendOptional(anchor)
      
      return (ProcessedResourceData.summary(.activity(patch)), anchors)
      
    case
      /// Body
      HKQuantityType.quantityType(forIdentifier: .bodyMass)!,
      HKQuantityType.quantityType(forIdentifier: .bodyFatPercentage)!:
      
      let (values, anchor) = try await queryQuantities(type: type)
      let patch = BodyPatch(sampleType: type, samples: values)
      
      anchors.appendOptional(anchor)
      
      return (ProcessedResourceData.summary(.body(patch)), anchors)
      
    default:
      return try await read(
        resource: typeToResource(type),
        healthKitStore: healthKitStore,
        typeToResource: typeToResource,
        vitalStorage: vitalStorage,
        startDate: startDate,
        endDate: endDate
      )
  }
}

func read(
  resource: VitalResource,
  healthKitStore: HKHealthStore,
  typeToResource: ((HKSampleType) -> VitalResource),
  vitalStorage: VitalHealthKitStorage?,
  startDate: Date,
  endDate: Date
) async throws -> (ProcessedResourceData, [StoredAnchor]) {
  
  switch resource {
    case .individual:
      
      let types = toHealthKitTypes(resource: resource)
      guard types.count == 1 else {
        fatalError("Individual types should made up of a single type. \(resource) isn't. This is a developer error")
      }
      
      guard let sampleType = types.first as? HKSampleType else {
        fatalError("\(types) is not an HKSampleType")
      }
      
      return try await read(
        type: sampleType,
        healthKitStore: healthKitStore,
        vitalStorage: vitalStorage,
        typeToResource: typeToResource,
        startDate: startDate,
        endDate: endDate
      )
      
    case .profile:
      let profilePayload = try await handleProfile(
        healthKitStore: healthKitStore
      )
      
      return (.summary(.profile(profilePayload)), [])
      
    case .body:
      let payload = try await handleBody(
        healthKitStore: healthKitStore,
        vitalStorage: vitalStorage,
        startDate: startDate,
        endDate: endDate
      )
      
      return (.summary(.body(payload.bodyPatch)), payload.anchors)
      
    case .sleep:
      let payload = try await handleSleep(
        healthKitStore: healthKitStore,
        vitalStorage: vitalStorage,
        startDate: startDate,
        endDate: endDate
      )
      
      return (.summary(.sleep(payload.sleepPatch)), payload.anchors)
      
    case .activity:
      let payload = try await handleActivity(
        healthKitStore: healthKitStore,
        vitalStorage: vitalStorage,
        startDate: startDate,
        endDate: endDate
      )
      
      return (.summary(.activity(payload.activityPatch)), payload.anchors)
      
    case .workout:
      let payload = try await handleWorkouts(
        healthKitStore: healthKitStore,
        vitalStorage: vitalStorage,
        startDate: startDate,
        endDate: endDate
      )
      
      return (.summary(.workout(payload.workoutPatch)), payload.anchors)
      
    case .vitals(.glucose):
      let payload = try await handleGlucose(
        healthKitStore: healthKitStore,
        vitalStorage: vitalStorage,
        startDate: startDate,
        endDate: endDate
      )
      
      return (.timeSeries(.glucose(payload.glucose)), payload.anchors)
      
    case .vitals(.hearthRate):
      let payload = try await handleHeartRate(
        healthKitStore: healthKitStore,
        vitalStorage: vitalStorage,
        startDate: startDate,
        endDate: endDate
      )
      
      return (.timeSeries(.heartRate(payload.heartrate)), payload.anchors)
      
    case .vitals(.bloodPressure):
      let payload = try await handleBloodPressure(
        healthKitStore: healthKitStore,
        vitalStorage: vitalStorage,
        startDate: startDate,
        endDate: endDate
      )
      
      return (.timeSeries(.bloodPressure(payload.bloodPressure)), payload.anchors)
  }
}

func handleProfile(
  healthKitStore: HKHealthStore
) async throws -> ProfilePatch {
  
  let sex = try healthKitStore.biologicalSex().biologicalSex
  let biologicalSex = ProfilePatch.BiologicalSex(healthKitSex: sex)
  
  var components = try healthKitStore.dateOfBirthComponents()
  components.timeZone = TimeZone(secondsFromGMT: 0)
  
  let dateOfBirth = components.date!
  
  let payload: [QuantitySample] = try await querySample(
    healthKitStore: healthKitStore,
    type: .quantityType(forIdentifier: .height)!,
    limit: 1,
    ascending: false
  ).compactMap(QuantitySample.init)
  
  let height = payload.last.map { Int($0.value)}
  
  return .init(
    biologicalSex: biologicalSex,
    dateOfBirth: dateOfBirth,
    height: height
  )
}

func handleBody(
  healthKitStore: HKHealthStore,
  vitalStorage: VitalHealthKitStorage?,
  startDate: Date,
  endDate: Date
) async throws -> (bodyPatch: BodyPatch, anchors: [StoredAnchor]) {
  
  func queryQuantities(
    type: HKSampleType
  ) async throws -> (quantities: [QuantitySample], StoredAnchor?) {
    
    let payload = try await query(
      healthKitStore: healthKitStore,
      vitalStorage: vitalStorage,
      type: type,
      startDate: startDate,
      endDate: endDate
    )
    
    let quantities: [QuantitySample] = payload.sample.compactMap(QuantitySample.init)
    return (quantities, payload.anchor)
  }
  
  
  var anchors: [StoredAnchor] = []
  
  let (bodyMass, bodyMassAnchor) = try await queryQuantities(
    type: .quantityType(forIdentifier: .bodyMass)!
  )
  
  var (bodyFatPercentage, bodyFatPercentageAnchor) = try await queryQuantities(
    type: .quantityType(forIdentifier: .bodyFatPercentage)!
  )
  
  bodyFatPercentage = bodyFatPercentage.map {
    var copy = $0
    copy.value = $0.value * 100
    return copy
  }
  
  anchors.appendOptional(bodyMassAnchor)
  anchors.appendOptional(bodyFatPercentageAnchor)
  
  return (
    .init(
      bodyMass: bodyMass,
      bodyFatPercentage: bodyFatPercentage
    ),
    anchors
  )
}

func handleSleep(
  healthKitStore: HKHealthStore,
  vitalStorage: VitalHealthKitStorage?,
  startDate: Date,
  endDate: Date
) async throws -> (sleepPatch: SleepPatch, anchors: [StoredAnchor]) {
    
  var anchors: [StoredAnchor] = []
  let sleepType = HKSampleType.categoryType(forIdentifier: .sleepAnalysis)!

  var predicate: NSPredicate?
  if #available(iOS 16.0, *) {
    predicate = HKCategoryValueSleepAnalysis.predicateForSamples(equalTo: HKCategoryValueSleepAnalysis.allAsleepValues)
  }
  
  let payload = try await query(
    healthKitStore: healthKitStore,
    vitalStorage: vitalStorage,
    type: sleepType,
    startDate: startDate,
    endDate: endDate,
    extraPredicate: predicate
  )
  
  /// An iPhone is capable of recording sleep. We can see it by looking at the bundle identifier + productType.
  /// However we are only interested in sleep recorded with an Apple Watch.
  /// This filter discards iPhone recorded sleeps.
  let sampleWithoutPhone = filterForWatch(samples: payload.sample)
  
  /// The goal of this filter is to remove sleep data generated by 3rd party apps that only do analyses.
  /// Apps like Pillow and SleepWatch are great, but we are only interested in data generated by devices (e.g. Apple Watch, Oura)
  let filteredSamples = filter(samples: sampleWithoutPhone, by: DataSource.allCases)

  let sleeps = filteredSamples.compactMap(SleepPatch.Sleep.init)
  
  /// Sleep samples can be sliced up. For example you can have a slice going from `2022-09-08 22:00` to `2022-09-08 22:15`
  /// And several others until the last one is `2022-09-09 07:00`. The goal of of `stichedSleeps` is to put all these slices together
  /// Into a single `SleepPatch.Sleep` going from  `2022-09-08 22:00` to `2022-09-08 22:15`
  let stitchedData = stichedSleeps(sleeps: sleeps)
  
  /// `stichedSleeps` doesn't deal with non-consecutive samples. So it's possible to have a sequence of samples that belong to different
  /// providers (e.g. Apple Watch, Oura, Fitbit). The goal of `mergeSleeps` is to find overlapping sleeps that belong to the same provider and merge them
  let mergedData = mergeSleeps(sleeps: stitchedData)
  
  anchors.appendOptional(payload.anchor)
  
  var copies: [SleepPatch.Sleep] = []
  
  for var sleep in mergedData {    
    func fitSamples(
      sleep: inout SleepPatch.Sleep
    ) {
      for filteredSample in filteredSamples {
        if let categorySample = filteredSample as? HKCategorySample,
           let sleepAnalysis = HKCategoryValueSleepAnalysis(rawValue: categorySample.value),
            filteredSample.sourceRevision.productType == sleep.productType &&
            filteredSample.sourceRevision.source.bundleIdentifier == sleep.sourceBundle &&
            filteredSample.startDate >= sleep.startDate && filteredSample.endDate <= sleep.endDate
            
        {
          let sample = QuantitySample(categorySample: categorySample)
          switch sleepAnalysis {
            case .asleepUnspecified:
              sleep.sleepStages.unspecifiedSleepSamples.append(sample)
              
            case .awake:
              sleep.sleepStages.awakeSleepSamples.append(sample)
              
            case .asleepCore:
              sleep.sleepStages.lightSleepSamples.append(sample)
              
            case .asleepREM:
              sleep.sleepStages.remSleepSamples.append(sample)
            
            case .asleepDeep:
              sleep.sleepStages.deepSleepSamples.append(sample)
              
            case .inBed:
              sleep.sleepStages.inBedSleepSamples.append(sample)
              
            @unknown default:
              sleep.sleepStages.unknownSleepSamples.append(sample)
          }
        }
      }
    }
    
    if #available(iOS 16.0, *) {
      fitSamples(sleep: &sleep)
    }
    
    let originalHR: [HKSample] = try await querySample(
      healthKitStore: healthKitStore,
      type: .quantityType(forIdentifier: .heartRate)!,
      startDate: sleep.startDate,
      endDate: sleep.endDate
    )
    
    let filteredHR = originalHR.filter(by: sleep.sourceBundle)
    let heartRate = filteredHR.compactMap(QuantitySample.init)
    
    let hearRateVariability: [QuantitySample] = try await querySample(
      healthKitStore: healthKitStore,
      type: .quantityType(forIdentifier: .heartRateVariabilitySDNN)!,
      startDate: sleep.startDate,
      endDate: sleep.endDate
    )
      .filter(by: sleep.sourceBundle)
      .compactMap(QuantitySample.init)
    
    let oxygenSaturation: [QuantitySample] = try await querySample(
      healthKitStore: healthKitStore,
      type: .quantityType(forIdentifier: .oxygenSaturation)!,
      startDate: sleep.startDate,
      endDate: sleep.endDate
    )
      .filter(by: sleep.sourceBundle)
      .compactMap(QuantitySample.init)
    
    let restingHeartRate: [QuantitySample] = try await querySample(
      healthKitStore: healthKitStore,
      type: .quantityType(forIdentifier: .restingHeartRate)!,
      startDate: sleep.startDate,
      endDate: sleep.endDate
    )
      .filter(by: sleep.sourceBundle)
      .compactMap(QuantitySample.init)
    
    let respiratoryRate: [QuantitySample] = try await querySample(
      healthKitStore: healthKitStore,
      type: .quantityType(forIdentifier: .respiratoryRate)!,
      startDate: sleep.startDate,
      endDate: sleep.endDate
    )
      .filter(by: sleep.sourceBundle)
      .compactMap(QuantitySample.init)
    
    var copy = sleep
    copy.heartRate = heartRate
    copy.heartRateVariability = hearRateVariability
    copy.restingHeartRate = restingHeartRate
    copy.oxygenSaturation = oxygenSaturation
    copy.respiratoryRate = respiratoryRate
    
    copies.append(copy)
  }
  
  return (.init(sleep: copies), anchors)
}

func handleActivity(
  healthKitStore: HKHealthStore,
  vitalStorage: VitalHealthKitStorage?,
  startDate: Date,
  endDate: Date
) async throws -> (activityPatch: ActivityPatch, anchors: [StoredAnchor]) {
  
  func queryQuantities(
    type: HKSampleType
  ) async throws -> (quantities: [QuantitySample], StoredAnchor?) {
    
    let payload = try await query(
      healthKitStore: healthKitStore,
      vitalStorage: vitalStorage,
      type: type,
      startDate: startDate,
      endDate: endDate
    )
    
    let quantities: [QuantitySample] = payload.sample.compactMap(QuantitySample.init)
    return (quantities, payload.anchor)
  }
  
  func queryStatistics(
    type: HKQuantityType
  ) async throws -> (quantities: [QuantitySample], StoredAnchor?) {
    
    let payload = try await queryStatisticsSample(
      healthKitStore: healthKitStore,
      vitalStorage: vitalStorage,
      type: type,
      startDate: startDate,
      endDate: endDate
    )
        
    let quantities: [QuantitySample] = payload.statistics.compactMap { value in
      return QuantitySample(value, type)
    }
    
    return (quantities, payload.anchor)
  }
  
  var anchors: [StoredAnchor] = []
  
  let (activeEnergyBurned, activeEnergyBurnedAnchor) = try await queryStatistics(
    type: .quantityType(forIdentifier: .activeEnergyBurned)!
  )
  
  let (basalEnergyBurned, basalEnergyBurnedAnchor) = try await queryStatistics(
    type: .quantityType(forIdentifier: .basalEnergyBurned)!
  )
  
  let (steps, stepsAnchor) = try await queryStatistics(
    type: .quantityType(forIdentifier: .stepCount)!
  )
  
  let (floorsClimbed, floorsClimbedAnchor) = try await queryStatistics(
    type: .quantityType(forIdentifier: .flightsClimbed)!
  )
  
  let (distanceWalkingRunning, distanceWalkingRunningAnchor) = try await queryStatistics(
    type: .quantityType(forIdentifier: .distanceWalkingRunning)!
  )
  
  let (vo2Max, vo2MaxAnchor) = try await queryQuantities(
    type: .quantityType(forIdentifier: .vo2Max)!
  )
  
  anchors.appendOptional(activeEnergyBurnedAnchor)
  anchors.appendOptional(basalEnergyBurnedAnchor)
  anchors.appendOptional(stepsAnchor)
  anchors.appendOptional(floorsClimbedAnchor)
  anchors.appendOptional(distanceWalkingRunningAnchor)
  anchors.appendOptional(vo2MaxAnchor)
  
  let allSamples = Array(
    [
      activeEnergyBurned,
      basalEnergyBurned,
      steps,
      floorsClimbed,
      distanceWalkingRunning,
      vo2Max
    ].joined()
  )
  
  let allDates: Set<Date> = Set(allSamples.reduce([]) { acc, next in
    acc + [next.startDate.dayStart]
  })
  
  let activities: [ActivityPatch.Activity] = allDates.map { date in
    func filter(_ samples: [QuantitySample]) -> [QuantitySample] {
      samples.filter { $0.startDate.dayStart == date }
    }
    
    return ActivityPatch.Activity(
      activeEnergyBurned: filter(activeEnergyBurned),
      basalEnergyBurned: filter(basalEnergyBurned),
      steps: filter(steps),
      floorsClimbed: filter(floorsClimbed),
      distanceWalkingRunning: filter(distanceWalkingRunning),
      vo2Max: filter(vo2Max)
    )
  }
  
  return (.init(activities: activities), anchors: anchors)
}

func handleWorkouts(
  healthKitStore: HKHealthStore,
  vitalStorage: VitalHealthKitStorage?,
  startDate: Date,
  endDate: Date
) async throws -> (workoutPatch: WorkoutPatch, anchors: [StoredAnchor]) {
  
  var anchors: [StoredAnchor] = []
  
  let payload = try await query(
    healthKitStore: healthKitStore,
    vitalStorage: vitalStorage,
    type: .workoutType(),
    startDate: startDate,
    endDate: endDate
  )
  
  let workouts = payload.sample.compactMap(WorkoutPatch.Workout.init)
  anchors.appendOptional(payload.anchor)
  
  var copies: [WorkoutPatch.Workout] = []
  
  for workout in workouts {
    let heartRate: [QuantitySample] = try await querySample(
      healthKitStore: healthKitStore,
      type: .quantityType(forIdentifier: .heartRate)!,
      startDate: workout.startDate,
      endDate: workout.endDate
    )
      .filter(by: workout.sourceBundle)
      .compactMap(QuantitySample.init)
    
    let respiratoryRate: [QuantitySample] = try await querySample(
      healthKitStore: healthKitStore,
      type: .quantityType(forIdentifier: .respiratoryRate)!,
      startDate: workout.startDate,
      endDate: workout.endDate
    )
      .filter(by: workout.sourceBundle)
      .compactMap(QuantitySample.init)
    
    var copy = workout
    copy.heartRate = heartRate
    copy.respiratoryRate = respiratoryRate
    
    copies.append(copy)
  }
  
  return (.init(workouts: copies), anchors)
}

func handleGlucose(
  healthKitStore: HKHealthStore,
  vitalStorage: VitalHealthKitStorage?,
  startDate: Date,
  endDate: Date
) async throws -> (glucose: [QuantitySample], anchors: [StoredAnchor]) {
  
  let bloodGlucoseType = HKSampleType.quantityType(forIdentifier: .bloodGlucose)!
  let payload = try await query(
    healthKitStore: healthKitStore,
    vitalStorage: vitalStorage,
    type: bloodGlucoseType,
    startDate: startDate,
    endDate: endDate
  )
  
  var anchors: [StoredAnchor] = []
  let glucose: [QuantitySample] = payload.sample.compactMap(QuantitySample.init)
  
  anchors.appendOptional(payload.anchor)
  
  return (glucose,anchors)
}

func handleBloodPressure(
  healthKitStore: HKHealthStore,
  vitalStorage: VitalHealthKitStorage?,
  startDate: Date,
  endDate: Date
) async throws -> (bloodPressure: [BloodPressureSample], anchors: [StoredAnchor]) {
  
  let bloodPressureIdentifier = HKCorrelationType.correlationType(forIdentifier: .bloodPressure)!
  
  let payload = try await query(
    healthKitStore: healthKitStore,
    vitalStorage: vitalStorage,
    type: bloodPressureIdentifier,
    startDate: startDate,
    endDate: endDate
  )
  
  var anchors: [StoredAnchor] = []
  let bloodPressure: [BloodPressureSample] = payload.sample.compactMap(BloodPressureSample.init)
  
  anchors.appendOptional(payload.anchor)
  
  return (bloodPressure: bloodPressure, anchors: anchors)
}

func handleHeartRate(
  healthKitStore: HKHealthStore,
  vitalStorage: VitalHealthKitStorage?,
  startDate: Date,
  endDate: Date
) async throws -> (heartrate: [QuantitySample], anchors: [StoredAnchor]) {
  
  let heartRateType = HKSampleType.quantityType(forIdentifier: .heartRate)!
  let payload = try await query(
    healthKitStore: healthKitStore,
    vitalStorage: vitalStorage,
    type: heartRateType,
    startDate: startDate,
    endDate: endDate
  )
  
  var anchors: [StoredAnchor] = []
  let glucose: [QuantitySample] = payload.sample.compactMap(QuantitySample.init)
  
  anchors.appendOptional(payload.anchor)
  
  return (glucose,anchors)
}

private func query(
  healthKitStore: HKHealthStore,
  vitalStorage: VitalHealthKitStorage? = nil,
  type: HKSampleType,
  limit: Int = HKObjectQueryNoLimit,
  startDate: Date? = nil,
  endDate: Date? = nil,
  extraPredicate: NSPredicate? = nil
) async throws -> (sample: [HKSample], anchor: StoredAnchor?) {
  
  return try await withCheckedThrowingContinuation { continuation in
    
    let handler: AnchorQueryHandler = { (query, samples, deletedObject, newAnchor, error) in
      healthKitStore.stop(query)
      
      if let error = error {
        continuation.resume(with: .failure(error))
        return
      }
      
      let storedAnchor = StoredAnchor(
        key: String(describing: type),
        anchor: newAnchor,
        date: Date(),
        vitalAnchors: nil
      )
      
      continuation.resume(with: .success((samples ?? [], storedAnchor)))
    }
    
    var predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: [])
    
    if let extraPredicate = extraPredicate {
      predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [predicate, extraPredicate])
    }
    
    let anchor = vitalStorage?.read(key: String(describing: type.self))?.anchor
    
    let query = HKAnchoredObjectQuery(
      type: type,
      predicate: predicate,
      anchor: anchor,
      limit: limit,
      resultsHandler: handler
    )
    
    healthKitStore.execute(query)
  }
}

/// TODO: To be Removed
private func populateAnchorsForStatisticalQuery(
  healthKitStore: HKHealthStore,
  vitalStorage: VitalHealthKitStorage?,
  type: HKQuantityType,
  startDate: Date,
  endDate: Date
) async {
  return await withCheckedContinuation { continuation in
    
    let handler: StatisticsHandler = { query, collection, error in
      healthKitStore.stop(query)
      
      let values: [HKStatistics] = collection?.statistics() ?? []
      let cleanedStatistics: [HKStatistics] = values.filter { statistic in
        isValidStatistic(statistic, type)
      }
      
      /// Generate new ids based on the read statistics values
      let ids = cleanedStatistics.compactMap { statistics in
        generateIdForAnchor(statistics, type).map(VitalAnchor.init(id:))
      }
      
      let storedAnchor = StoredAnchor(
        key: String(describing: type),
        anchor: nil,
        date: endDate,
        vitalAnchors: ids
      )
      
      vitalStorage?.store(entity: storedAnchor)
      continuation.resume()
    }
    
    let predicate = HKQuery.predicateForSamples(
      withStart: startDate,
      end: endDate,
      options: [.strictStartDate]
    )
    
    let query = HKStatisticsCollectionQuery(
      quantityType: type,
      quantitySamplePredicate: predicate,
      options: .cumulativeSum,
      anchorDate: startDate,
      intervalComponents: .init(hour: 1)
    )
    
    query.initialResultsHandler = handler
    
    healthKitStore.execute(query)
  }
}


private func queryStatisticsSample(
  healthKitStore: HKHealthStore,
  vitalStorage: VitalHealthKitStorage?,
  type: HKQuantityType,
  startDate: Date,
  endDate: Date
) async throws -> (statistics: [HKStatistics], anchor: StoredAnchor) {
  
  let date = vitalStorage?.read(key: String(describing: type.self))?.date
  let withStart = (date ?? startDate).dayStart
  let withEnd = endDate.nextHour
  
  print(withStart)
  print(withEnd)
  
  let calendar = vitalCalendar
  /// If this is nil, it means the user is still in the old system.
  /// We need to populate existing anchors, so that we send the correct data.
  /// TODO: Remove this in the near future
  ///
  ///
  /// <TO BE REMOVED>
  let existingAnchors = vitalStorage?.read(key: String(describing: type.self))?.vitalAnchors
  if existingAnchors == nil {
    /// We will fill up 7 days worth of data on the anchors side
    let sevenDaysAgo = calendar.date(byAdding: .day, value: -2, to: withStart)
    
    print("==Populate Anchors==")
    print(sevenDaysAgo)
    print(withStart)
    
    await populateAnchorsForStatisticalQuery(
      healthKitStore: healthKitStore,
      vitalStorage: vitalStorage,
      type: type,
      startDate: sevenDaysAgo!,
      endDate: withStart
    )
  }
  ///
  /// </TO BE REMOVED>
  
  return try await withCheckedThrowingContinuation { continuation in
    
    let handler: StatisticsHandler = { query, collection, error in
      healthKitStore.stop(query)
      
      if let error = error {
        continuation.resume(with: .failure(error))
        return
      }
      
      let values: [HKStatistics] = collection?.statistics() ?? []
      let cleanedStatistics: [HKStatistics] = values.filter { statistic in
        isValidStatistic(statistic, type)
      }
      
      /// Generate new ids based on the read statistics values
      let newIds = cleanedStatistics.compactMap { statistics in
        generateIdForAnchor(statistics, type).map(VitalAnchor.init(id:))
      }
      
      /// Get the existing keys
      let existingIds = vitalStorage?.read(key: String(describing: type.self))?.vitalAnchors ?? []
      
      /// There's a difference between what we want to send to the server, versus what we want to store
      /// The ones to send, is the delta between the new versus the existing.
      let toSendIds = anchorsToSend(old: existingIds, new: newIds)
      
      /// We can now filter the statistics that match the ids we want to send
      /// We also clean-up the values with zero
      let dataToSend = cleanedStatistics.filter { statistics in
        guard let id = generateIdForAnchor(statistics, type) else {
          return false
        }
        
        return toSendIds.map(\.id).contains(id)
      }
      
      /// The ones to store is a union of all ids.
      let toStoreIds = anchorsToStore(old: existingIds, new: newIds)

      let storedAnchor = StoredAnchor(
        key: String(describing: type),
        anchor: nil,
        date: endDate,
        vitalAnchors: toStoreIds
      )
      
      continuation.resume(with: .success((dataToSend, storedAnchor)))
    }
    
    /// Because there are no anchors, we might miss data that was inserted before our "date anchor".
    /// E.g. Anchor date is set to 16:00. Another app inserts steps at 15:00. If we don't check at least two days
    /// before, we might run the risk of losing the insered steps at 15:00.
    /// We might need to extend this value to a week.
    let twoDaysAgo = calendar.date(byAdding: .day, value: -1, to: withStart)
    
    print("==Normal Query==")
    print(twoDaysAgo)
    print(endDate)
        
    let predicate = HKQuery.predicateForSamples(
      withStart: twoDaysAgo,
      end: endDate,
      options: [.strictStartDate]
    )
    
    let query = HKStatisticsCollectionQuery(
      quantityType: type,
      quantitySamplePredicate: predicate,
      options: .cumulativeSum,
      anchorDate: startDate,
      intervalComponents: .init(hour: 1)
    )
  
    query.initialResultsHandler = handler
    
    healthKitStore.execute(query)
  }
}

private func querySample(
  healthKitStore: HKHealthStore,
  type: HKSampleType,
  limit: Int = HKObjectQueryNoLimit,
  startDate: Date? = nil,
  endDate: Date? = nil,
  ascending: Bool = true
) async throws -> [HKSample] {
  
  return try await withCheckedThrowingContinuation { continuation in
    
    let handler: SampleQueryHandler = { (query, samples, error) in
      healthKitStore.stop(query)
      
      if let error = error {
        continuation.resume(with: .failure(error))
        return
      }
      
      continuation.resume(with: .success(samples ?? []))
    }
    
    let predicate = HKQuery.predicateForSamples(
      withStart: startDate,
      end: endDate,
      options: [.strictStartDate]
    )
    
    let sort = [
      NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: ascending)
    ]
    
    let query = HKSampleQuery(
      sampleType: type,
      predicate: predicate,
      limit: limit,
      sortDescriptors: sort,
      resultsHandler: handler
    )
    
    healthKitStore.execute(query)
  }
}

private func querySeries(
  healthKitStore: HKHealthStore,
  type: HKQuantityType,
  startDate: Date,
  endDate: Date
) async throws -> [HKQuantity] {
  
  return try await withCheckedThrowingContinuation { continuation in
    
    var quantities: [HKQuantity] = []
    let handler: SeriesSampleHandler = { (query, quantity, dateInterval, sample, isFinished, error) in
      healthKitStore.stop(query)
      if let error = error {
        continuation.resume(with: .failure(error))
        return
      }
      
      if let quantity = quantity {
        quantities.append(quantity)
      }
      
      if isFinished {
        continuation.resume(with: .success(quantities))
      }
    }
    
    
    let predicate = HKQuery.predicateForSamples(
      withStart: startDate,
      end: endDate,
      options: [.strictStartDate]
    )
    
    let query = HKQuantitySeriesSampleQuery(
      quantityType: type,
      predicate: predicate,
      quantityHandler: handler
    )
    
    healthKitStore.execute(query)
  }
}

private func activityQuery(
  healthKitStore: HKHealthStore,
  startDate: Date,
  endDate: Date
) async throws -> [HKActivitySummary] {
  
  return try await withCheckedThrowingContinuation { continuation in
    
    let handler: ActivityQueryHandler = { (query, activities, error) in
      healthKitStore.stop(query)
      
      if let error = error {
        continuation.resume(with: .failure(error))
        return
      }
      
      continuation.resume(with: .success(activities ?? []))
    }
    
    let startDateComponent = startDate.dateComponentsForActivityQuery
    let endDateComponent = endDate.dateComponentsForActivityQuery
    
    let predicate = HKQuery.predicate(forActivitySummariesBetweenStart: startDateComponent, end: endDateComponent)
    let query = HKActivitySummaryQuery(predicate: predicate, resultsHandler: handler)
    
    healthKitStore.execute(query)
  }
}

func mergeSleeps(sleeps: [SleepPatch.Sleep]) -> [SleepPatch.Sleep] {
  
  func compareSleep(
    sleeps: [SleepPatch.Sleep],
    sleep: SleepPatch.Sleep
  ) -> [SleepPatch.Sleep] {

    for (index, value) in sleeps.enumerated() {
      
      if
        (value.startDate ... value.endDate).overlaps(sleep.startDate ... sleep.endDate) &&
        value.sourceBundle == sleep.sourceBundle
      {
        
        var copySleep = sleep
        copySleep.startDate = min(value.startDate, copySleep.startDate)
        copySleep.endDate = max(value.endDate, copySleep.endDate)
        
        var copySleeps = sleeps
        copySleeps.remove(at: index)
        
        return compareSleep(sleeps: copySleeps, sleep: copySleep)
      }
    }

    return sleeps + [sleep]
  }

  let sanityCheck = sleeps.filter {
    $0.endDate >= $0.startDate
  }
  
  return sanityCheck.reduce(into: []) { acc, sleep in
    acc = compareSleep(sleeps: acc, sleep: sleep)
  }
}

func stichedSleeps(sleeps: [SleepPatch.Sleep]) -> [SleepPatch.Sleep] {
  return sleeps.reduce(into: []) { acc, newSleep in
    
    guard var lastValue = acc.last else {
      acc = [newSleep]
      return
    }
    
    guard lastValue.sourceBundle == newSleep.sourceBundle else {
      acc = acc + [newSleep]
      return
    }
    
    /// A) `newSleep` happens after `lastValue`
    ///
    /// |____________|   <->  |____________|
    ///    lastValue     30m     newSleep
    if newSleep.startDate > lastValue.endDate  {
      
      /// It happens in less than 30 minutes
      if isLongerThan30Minutes(firstDate: lastValue.endDate, secondDate: newSleep.startDate) == false {
        let newAcc = acc.dropLast()
        lastValue.endDate = newSleep.endDate
        acc = newAcc + [lastValue]
        return
      }
    }
    
    /// B) `lastValue` happens after `newSleep`
    ///
    /// |____________|  <->  |____________|
    ///    newSleep     30m     lastValue
    if lastValue.startDate > newSleep.endDate  {
      let longerThanThirtyMinutes = isLongerThan30Minutes(firstDate: newSleep.endDate, secondDate: lastValue.startDate)
      
      /// It happens in less than 30 minutes
      if longerThanThirtyMinutes == false {
        let newAcc = acc.dropLast()
        lastValue.startDate = newSleep.startDate
        acc = newAcc + [lastValue]
        return
      }
    }
    
    /// C) `lastValue` overlaps `newSleep` (and vice-versa)
    ///
    /// |____________|
    ///    newSleep
    ///       |____________|
    ///         lastValue
    
    if (lastValue.startDate ... lastValue.endDate).overlaps(newSleep.startDate ... newSleep.endDate) {
      let newAcc = acc.dropLast()
      
      lastValue.startDate = min(lastValue.startDate, newSleep.startDate)
      lastValue.endDate = max(lastValue.endDate, newSleep.endDate)
      
      acc = newAcc + [lastValue]
      return
    }
    
    /// There's no overlap, or the difference is more than 30 minutes.
    /// It's likely a completely new entry
    acc = acc + [newSleep]
  }
}

private func filterForWatch(samples: [HKSample]) -> [HKSample] {
  return samples.filter { sample in
    let bundleIdentifier = sample.sourceRevision.source.bundleIdentifier
    
    if bundleIdentifier.contains(DataSource.appleHealthKit.rawValue) {
      
      /// Data generated from a watch can look like this `Optional("Watch4,4")`
      if let productType = sample.sourceRevision.productType {
        return productType.lowercased().contains("watch")
      } else {
        /// We don't know what this is.
        return false
      }
      
    } else {
      /// This sample was made by something else besides com.apple.healthkit
      /// So we allow it
      return true
    }
  }
}

private func filter(samples: [HKSample], by dataSources: [DataSource]) -> [HKSample] {
  return samples.filter { sample in
    let identifier = sample.sourceRevision.source.bundleIdentifier
    
    for dataSource in dataSources {
      if identifier.contains(dataSource.rawValue) {
        return true
      }
    }
    
    return false
  }
}

private func filter(samples: [HKSample], on productType: String, sourceBundle: String) -> [HKSample] {
  return samples.filter { sample in
    return sample.sourceRevision.productType == productType &&
    sample.sourceRevision.source.bundleIdentifier == sourceBundle
  }
}

private func isLongerThan30Minutes(firstDate: Date, secondDate: Date) -> Bool {
  let diff = abs(firstDate.timeIntervalSinceReferenceDate - secondDate.timeIntervalSinceReferenceDate)
  let longerThanThirtyMinutes = diff > 60 * 30
  return longerThanThirtyMinutes
}

private func orderByDate(_ values: [QuantitySample]) -> [QuantitySample] {
  return values.sorted { $0.startDate < $1.startDate }
}

func splitPerBundle(_ values: [QuantitySample]) -> [[QuantitySample]] {
  var temp: [String: [QuantitySample]] = ["na": []]
  
  for value in values {
    if let bundle = value.sourceBundle {
      if temp[bundle] != nil {
        var copy = temp[bundle]!
        copy.append(value)
        temp[bundle] = copy
      } else {
        temp[bundle] = [value]
      }
    } else {
      var copy = temp["na"]!
      copy.append(value)
      temp["na"] = copy
    }
  }
  
  var outcome: [[QuantitySample]] = [[]]
  
  for key in temp.keys {
    let samples = temp[key]!
    outcome.append(samples)
  }
  
  return outcome
}

private func _accumulate(_ values: [QuantitySample], interval: Int, calendar: Calendar) -> [QuantitySample] {
  let ordered = orderByDate(values)
  
  return ordered.reduce(into: []) { newValues, newValue in
    if let lastValue = newValues.last {
      
      let sameHour = calendar.isDate(newValue.startDate, equalTo: lastValue.startDate, toGranularity: .hour)
      
      guard sameHour else {
        newValues.append(newValue)
        return
      }
      
      let lastValueBucket = Int(calendar.component(.minute, from: lastValue.startDate) / interval)
      let newValueBucket = Int(calendar.component(.minute, from: newValue.startDate) / interval)
      
      guard lastValueBucket == newValueBucket else {
        newValues.append(newValue)
        return
      }
      
      var lastValue = newValues.removeLast()
      lastValue.value = lastValue.value + newValue.value
      lastValue.endDate = newValue.endDate
      
      newValues.append(lastValue)
      
    } else {
      newValues.append(newValue)
    }
  }
}

func accumulate(_ values: [QuantitySample], interval: Int = 15, calendar: Calendar) -> [QuantitySample] {
  let split = splitPerBundle(values)
  let outcome = split.flatMap {
    _accumulate($0, interval: interval, calendar: calendar)
  }
  
  return orderByDate(outcome)
}

func removeZeros(_ values: [QuantitySample]) -> [QuantitySample] {
  return values.filter {
    $0.value != 0
  }
}


private func _average(_ values: [QuantitySample], calendar: Calendar) -> [QuantitySample] {
  let ordered = orderByDate(values)
  
  guard ordered.count > 2 else {
    return values
  }
  
  /// We want to preserve these values, instead of averaging them.
  var min: QuantitySample? = nil
  var max: QuantitySample? = nil
  
  for value in values {
    if let minValue = min {
      if value.value <= minValue.value {
        min = value
      }
    } else {
      min = value
    }
    
    if let maxValue = max {
      if value.value >= maxValue.value {
        max = value
      }
    } else {
      max = value
    }
  }
  
  class Payload {
    var samples: [QuantitySample] = []
    var total: Double = 0
    var totalGrouped: Double = 0
    var count = 0
  }
  
  var outcome: [QuantitySample] = ordered.reduce(into: Payload()) { payload, newValue in
    payload.count = payload.count + 1
    
    if let lastValue = payload.samples.last {
      
      let time = calendar.date(byAdding: .second, value: 5, to: lastValue.startDate)!
      if time >= newValue.startDate {
        var lastValue = payload.samples.removeLast()
        
        payload.total = payload.total + newValue.value
        payload.totalGrouped = payload.totalGrouped + 1
        lastValue.endDate = newValue.endDate
        
        if payload.count == ordered.count {
          lastValue.value = payload.total / payload.totalGrouped
        }
        
        payload.samples.append(lastValue)
      } else {
        var lastValue = payload.samples.removeLast()
        lastValue.value = payload.total / payload.totalGrouped
        payload.samples.append(lastValue)
        
        payload.total = newValue.value
        payload.totalGrouped = 1
        
        payload.samples.append(newValue)
      }
      
    } else {
      payload.total = newValue.value
      payload.totalGrouped = payload.totalGrouped + 1
      payload.samples.append(newValue)
    }
  }.samples
  
  if let max = max {
    outcome.append(max)
  }
  
  if let min = min {
    outcome.append(min)
  }
  
  return outcome
}

func average(_ values: [QuantitySample], calendar: Calendar) -> [QuantitySample] {
  let split = splitPerBundle(values)
  let outcome = split.flatMap {
    _average($0, calendar: calendar)
  }
  
  return orderByDate(outcome)
}
