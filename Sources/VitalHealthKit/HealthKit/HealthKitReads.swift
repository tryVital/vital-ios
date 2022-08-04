import HealthKit
import VitalCore

typealias SampleQueryHandler = (HKSampleQuery, [HKSample]?, Error?) -> Void
typealias AnchorQueryHandler = (HKAnchoredObjectQuery, [HKSample]?, [HKDeletedObject]?, HKQueryAnchor?, Error?) -> Void
typealias ActivityQueryHandler = (HKActivitySummaryQuery, [HKActivitySummary]?, Error?) -> Void

typealias SeriesSampleHandler = (HKQuantitySeriesSampleQuery, HKQuantity?, DateInterval?, HKQuantitySample?, Bool, Error?) -> Void


func read(
  type: HKSampleType,
  stage: TaggedPayload.Stage,
  healthKitStore: HKHealthStore,
  vitalStorage: VitalHealthKitStorage,
  startDate: Date,
  endDate: Date
) async throws -> (PostResourceData, [StoredAnchor]) {
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
  
  /// If it's an historical read (aka the first read)
  /// We will try to get all the data first, rather than individual samples
  guard stage.isDaily else {
    return try await read(
      resource: type.toVitalResource,
      healthKitStore: healthKitStore,
      vitalStorage: vitalStorage,
      startDate: startDate,
      endDate: endDate
    )
  }
  
  var anchors: [StoredAnchor] = []
  
  switch type {
    case
      /// Activity
      HKSampleType.quantityType(forIdentifier: .activeEnergyBurned)!,
      HKSampleType.quantityType(forIdentifier: .basalEnergyBurned)!,
      HKSampleType.quantityType(forIdentifier: .stepCount)!,
      HKSampleType.quantityType(forIdentifier: .flightsClimbed)!,
      HKSampleType.quantityType(forIdentifier: .distanceWalkingRunning)!,
      HKSampleType.quantityType(forIdentifier: .vo2Max)!:
      
      let (values, anchor) = try await queryQuantities(type: type)
      let patch = ActivityPatch(sampleType: type, samples: values)
      
      anchors.appendOptional(anchor)
      
      return (PostResourceData.summary(.activity(patch)), anchors)
      
    case
      /// Body
      HKQuantityType.quantityType(forIdentifier: .bodyMass)!,
      HKQuantityType.quantityType(forIdentifier: .bodyFatPercentage)!:
      
      let (values, anchor) = try await queryQuantities(type: type)
      let patch = BodyPatch(sampleType: type, samples: values)
      
      anchors.appendOptional(anchor)
      
      return (PostResourceData.summary(.body(patch)), anchors)
      
    default:
      return try await read(
        resource: type.toVitalResource,
        healthKitStore: healthKitStore,
        vitalStorage: vitalStorage,
        startDate: startDate,
        endDate: endDate
      )
  }
}

func read(
  resource: VitalResource,
  healthKitStore: HKHealthStore,
  vitalStorage: VitalHealthKitStorage,
  startDate: Date,
  endDate: Date
) async throws -> (PostResourceData, [StoredAnchor]) {
  
  switch resource {
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
  vitalStorage: VitalHealthKitStorage,
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
  vitalStorage: VitalHealthKitStorage,
  startDate: Date,
  endDate: Date
) async throws -> (sleepPatch: SleepPatch, anchors: [StoredAnchor]) {
  
  var anchors: [StoredAnchor] = []
  let sleepType = HKSampleType.categoryType(forIdentifier: .sleepAnalysis)!
  
  let payload = try await query(
    healthKitStore: healthKitStore,
    vitalStorage: vitalStorage,
    type: sleepType,
    startDate: startDate,
    endDate: endDate
  )
  
  /// An iPhone is capable of recording sleep. We can see it by looking at the bundle identifier + productType.
  /// However we are only interested in sleep recorded with an Apple Watch.
  /// This filter discards iPhone recorded sleeps.
  let sampleWithoutPhone = filterForWatch(samples: payload.sample)
  
  /// The goal of this filter is to remove sleep data generated by 3rd party apps that only do analyses.
  /// Apps like Pillow and SleepWatch are great, but we are only interested in data generated by devices (e.g. Apple Watch, Oura)
  let filteredSamples = filter(samples: sampleWithoutPhone, by: DataSource.allCases)

  let sleeps = filteredSamples.compactMap(SleepPatch.Sleep.init)
  let stitchedData = stichedSleeps(sleeps: sleeps)
  let mergedData = mergeSleeps(sleeps: stitchedData)
  
  anchors.appendOptional(payload.anchor)
  
  var copies: [SleepPatch.Sleep] = []
  
  for sleep in mergedData {
    
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
  vitalStorage: VitalHealthKitStorage,
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
  
  var anchors: [StoredAnchor] = []
  
  
  let (activeEnergyBurned, activeEnergyBurnedAnchor) = try await queryQuantities(
    type: .quantityType(forIdentifier: .activeEnergyBurned)!
  )
  
  let (basalEnergyBurned, basalEnergyBurnedAnchor) = try await queryQuantities(
    type: .quantityType(forIdentifier: .basalEnergyBurned)!
  )
  
  let (steps, stepsAnchor) = try await queryQuantities(
    type: .quantityType(forIdentifier: .stepCount)!
  )
  
  let (floorsClimbed, floorsClimbedAnchor) = try await queryQuantities(
    type: .quantityType(forIdentifier: .flightsClimbed)!
  )
  
  let (distanceWalkingRunning, distanceWalkingRunningAnchor) = try await queryQuantities(
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
      date: date,
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
  vitalStorage: VitalHealthKitStorage,
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
  vitalStorage: VitalHealthKitStorage,
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
  vitalStorage: VitalHealthKitStorage,
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
  vitalStorage: VitalHealthKitStorage,
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
  endDate: Date? = nil
) async throws -> (sample: [HKSample], anchor: StoredAnchor?) {
  
  return try await withCheckedThrowingContinuation { continuation in
    
    let handler: AnchorQueryHandler = { (query, samples, deletedObject, newAnchor, error) in
      healthKitStore.stop(query)
      
      if let error = error {
        continuation.resume(with: .failure(error))
        return
      }
      
      let storedAnchor = StoredAnchor.init(key: String(describing: type), anchor: newAnchor)
      continuation.resume(with: .success((samples ?? [], storedAnchor)))
    }
    
    let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: [])
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

private func mergeSleeps(sleeps: [SleepPatch.Sleep]) -> [SleepPatch.Sleep] {
  func _mergeSleeps(sleeps: [SleepPatch.Sleep], sleep: SleepPatch.Sleep) -> [SleepPatch.Sleep] {
  
    for value in sleeps {
      if (value.startDate ... value.endDate).overlaps(sleep.startDate ... sleep.endDate) && value.sourceBundle == sleep.sourceBundle {
        
        let diffExisting = value.endDate.timeIntervalSinceReferenceDate - value.startDate.timeIntervalSinceReferenceDate
        let diffNew = sleep.endDate.timeIntervalSinceReferenceDate - sleep.startDate.timeIntervalSinceReferenceDate
        
        if diffExisting > diffNew {
          return sleeps
        } else {
          let newAcc = Array(sleeps.dropLast())
          return _mergeSleeps(sleeps: newAcc, sleep: sleep)
        }
      }
    }
    
    return sleeps + [sleep]
  }
  
  
  return sleeps.reduce([]) { acc, sleep in
    return _mergeSleeps(sleeps: acc, sleep: sleep)
  }
}

private func stichedSleeps(sleeps: [SleepPatch.Sleep]) -> [SleepPatch.Sleep] {
  return sleeps.reduce([]) { acc, sleep in
    
    guard var lastValue = acc.last else {
      return [sleep]
    }
    
    let diff = sleep.startDate.timeIntervalSinceReferenceDate - lastValue.endDate.timeIntervalSinceReferenceDate
    let longerThanThirtyMinutes = diff > 60 * 30
    
    if longerThanThirtyMinutes == false && lastValue.sourceBundle == sleep.sourceBundle {
      
      let newAcc = acc.dropLast()
      lastValue.endDate = sleep.endDate
      
      return newAcc + [lastValue]
    }
    
    return acc + [sleep]
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
