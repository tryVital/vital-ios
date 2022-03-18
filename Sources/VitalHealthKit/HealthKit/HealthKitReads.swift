import HealthKit

typealias SampleQueryHandler = (HKSampleQuery, [HKSample]?, Error?) -> Void
typealias AnchorQueryHandler = (HKAnchoredObjectQuery, [HKSample]?, [HKDeletedObject]?, HKQueryAnchor?, Error?) -> Void
typealias ActivityQueryHandler = (HKActivitySummaryQuery, [HKActivitySummary]?, Error?) -> Void

typealias SeriesSampleHandler = (HKQuantitySeriesSampleQuery, HKQuantity?, DateInterval?, HKQuantitySample?, Bool, Error?) -> Void


func handle(
  domain: Domain,
  store: HKHealthStore,
  vitalStorage: VitalStorage,
  isBackgroundUpdating: Bool,
  startDate: Date = .dateAgo(days: 30),
  endDate: Date = .init()
) async throws -> (AnyEncodable, [StoredEntity]) {

  switch domain {
    case .profile:
      let profilePayload = try await handleProfile(
        healthKitStore: store,
        vitalStorage: vitalStorage
      ).eraseToAnyEncodable()
      
      return (profilePayload, [])
      
    case .body:
      let payload = try await handleBody(
        healthKitStore: store,
        vitalStorage: vitalStorage,
        isBackgroundUpdating: isBackgroundUpdating
      )
        
      let body = payload.bodyPatch.eraseToAnyEncodable()
      let entitiesToStore = payload.anchors.map { StoredEntity.anchor($0.key, $0.value) }
      
      return (body, entitiesToStore)
      
    case .sleep:
      let payload = try await handleSleep(
        healthKitStore: store,
        vitalStorage: vitalStorage,
        isBackgroundUpdating: isBackgroundUpdating
      )
        
      let sleep = payload.sleepPatch.eraseToAnyEncodable()
      let entitiesToStore = payload.anchors.map { StoredEntity.anchor($0.key, $0.value) }

      return (sleep, entitiesToStore)
      
    case .activity:
      let payload = try await handleActivity(
        healthKitStore: store,
        vitalStorage: vitalStorage
      )
      
      let activity = payload.acitivtyPatch.eraseToAnyEncodable()
      let data = payload.lastActivityDate == nil ? [] : [StoredEntity.date(VitalStorage.activitiesKey, payload.lastActivityDate!)]
      
      return (activity, data)
      
    case .workout:
      let payload = try await handleWorkouts(
        healthKitStore: store,
        vitalStorage: vitalStorage,
        isBackgroundUpdating: isBackgroundUpdating
      )
        
      let workout = payload.workoutPatch.eraseToAnyEncodable()
      let entitiesToStore = payload.anchors.map { StoredEntity.anchor($0.key, $0.value) }

      return (workout, entitiesToStore)
      
    case .vitals(.glucose):
      let payload = try await handleGlucose(
        healthKitStore: store,
        vitalStorage: vitalStorage,
        isBackgroundUpdating: isBackgroundUpdating
      )
        
      let glucose = payload.glucosePatch.eraseToAnyEncodable()
      let entitiesToStore = payload.anchors.map { StoredEntity.anchor($0.key, $0.value) }

      return (glucose, entitiesToStore)
  }
}

func handleProfile(
  healthKitStore: HKHealthStore,
  vitalStorage: VitalStorage
) async throws -> VitalProfilePatch {
  
  let sex = try healthKitStore.biologicalSex().biologicalSex
  let biologicalSex = VitalProfilePatch.BiologicalSex(healthKitSex: sex)
  
  let dateOfBirth = try healthKitStore.dateOfBirthComponents().date
  
  return .init(biologicalSex: biologicalSex, dateOfBirth: dateOfBirth)
}

func handleBody(
  healthKitStore: HKHealthStore,
  vitalStorage: VitalStorage,
  isBackgroundUpdating: Bool,
  startDate: Date = .dateAgo(days: 30),
  endDate: Date = .init()
) async throws -> (bodyPatch: VitalBodyPatch, anchors: [String: HKQueryAnchor]) {
  
  func queryQuantities(
    type: HKSampleType,
    unit: QuantitySample.Unit
  ) async throws -> (quantities: [QuantitySample], (key: String, anchor: HKQueryAnchor? )) {
    
    let payload = try await query(
      healthKitStore: healthKitStore,
      vitalStorage: vitalStorage,
      isBackgroundUpdating: isBackgroundUpdating,
      type: type,
      startDate: startDate,
      endDate: endDate
    )
  
    let quantities: [QuantitySample] = payload.sample.compactMap {
      .init($0, unit: unit)
    }
    
    return (quantities, (String(describing: type), payload.anchor))
  }
  
  var anchors: [String: HKQueryAnchor] = [:]
  
  let (height, heightAnchor) = try await queryQuantities(
    type: .quantityType(forIdentifier: .height)!,
    unit: .height
  )
  
  let (bodyMass, bodyMassAnchor) = try await queryQuantities(
    type: .quantityType(forIdentifier: .bodyMass)!,
    unit: .bodyMass
  )
  
  let (bodyFatPercentage, bodyFatPercentageAnchor) = try await queryQuantities(
    type: .quantityType(forIdentifier: .bodyFatPercentage)!,
    unit: .bodyFatPercentage
  )
  
  anchors.setSafely(heightAnchor.anchor, key: heightAnchor.key)
  anchors.setSafely(bodyMassAnchor.anchor, key: bodyMassAnchor.key)
  anchors.setSafely(bodyFatPercentageAnchor.anchor, key: bodyFatPercentageAnchor.key)
  
  return (.init(
              height: height,
              bodyMass: bodyMass,
              bodyFatPercentage: bodyFatPercentage
          ),
          anchors
        )
}

func handleSleep(
  healthKitStore: HKHealthStore,
  vitalStorage: VitalStorage,
  isBackgroundUpdating: Bool,
  startDate: Date = .dateAgo(days: 30),
  endDate: Date = .init()
) async throws -> (sleepPatch: VitalSleepPatch, anchors: [String: HKQueryAnchor]) {
  
  var anchors: [String: HKQueryAnchor] = [:]
  let sleepType = HKSampleType.categoryType(forIdentifier: .sleepAnalysis)!

  let payload = try await query(
    healthKitStore: healthKitStore,
    vitalStorage: vitalStorage,
    isBackgroundUpdating: isBackgroundUpdating,
    type: sleepType,
    startDate: startDate,
    endDate: endDate
  )
  
  let sleeps = payload.sample.compactMap(VitalSleepPatch.Sleep.init)
  anchors.setSafely(payload.anchor, key: String(describing: sleepType))

  var copies: [VitalSleepPatch.Sleep] = []
  
  for sleep in sleeps {
    
    let heartRate: [QuantitySample] = try await querySample(
      healthKitStore: healthKitStore,
      type: .quantityType(forIdentifier: .heartRate)!,
      startDate: sleep.startDate,
      endDate: sleep.endDate
    ).compactMap { .init($0, unit: .heartRate) }
    
    let hearRateVariability: [QuantitySample] = try await querySample(
      healthKitStore: healthKitStore,
      type: .quantityType(forIdentifier: .heartRateVariabilitySDNN)!,
      startDate: sleep.startDate,
      endDate: sleep.endDate
    ).compactMap { .init($0, unit: .heartRateVariability) }
    
    let oxygenSaturation: [QuantitySample] = try await querySample(
      healthKitStore: healthKitStore,
      type: .quantityType(forIdentifier: .oxygenSaturation)!,
      startDate: sleep.startDate,
      endDate: sleep.endDate
    ).compactMap { .init($0, unit: .oxygenSaturation) }
    
    let restingHeartRate: [QuantitySample] = try await querySample(
      healthKitStore: healthKitStore,
      type: .quantityType(forIdentifier: .restingHeartRate)!,
      startDate: sleep.startDate,
      endDate: sleep.endDate
    ).compactMap { .init($0, unit: .restingHeartRate) }
    
    let respiratoryRate: [QuantitySample] = try await querySample(
      healthKitStore: healthKitStore,
      type: .quantityType(forIdentifier: .respiratoryRate)!,
      startDate: sleep.startDate,
      endDate: sleep.endDate
    ).compactMap { .init($0, unit: .restingHeartRate) }
    
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
  vitalStorage: VitalStorage
) async throws -> (acitivtyPatch: VitalActivityPatch, lastActivityDate: Date?) {
  
  let startDate = vitalStorage.read(key: VitalStorage.activitiesKey)?.date ?? .dateAgo(days: 30)
  let endDate: Date = .init()
  
  let activities = try await activityQuery(
    healthKitStore: healthKitStore,
    startDate: startDate,
    endDate: endDate
  ).map(VitalActivityPatch.Activity.init)
  
  var copies: [VitalActivityPatch.Activity] = []
  
  for activity in activities {
    guard let date = activity.date else {
      copies.append(activity)
      continue
    }
    
    let beginningOfDay = date.beginningOfDay
    let endingOfDay = date.endingOfDay

    let basalEnergyBurned: [QuantitySample] = try await querySample(
      healthKitStore: healthKitStore,
      type: .quantityType(forIdentifier: .basalEnergyBurned)!,
      startDate: beginningOfDay,
      endDate: endingOfDay
    ).compactMap { .init($0, unit: .basalEnergyBurned) }
    
    let steps: [QuantitySample] = try await querySample(
      healthKitStore: healthKitStore,
      type: .quantityType(forIdentifier: .stepCount)!,
      startDate: beginningOfDay,
      endDate: endingOfDay
    ).compactMap { .init($0, unit: .steps) }
    
    let floorsClimbed: [QuantitySample] = try await querySample(
      healthKitStore: healthKitStore,
      type: .quantityType(forIdentifier: .flightsClimbed)!,
      startDate: beginningOfDay,
      endDate: endingOfDay
    ).compactMap { .init($0, unit: .floorsClimbed) }
    
    let distanceWalkingRunning: [QuantitySample] = try await querySample(
      healthKitStore: healthKitStore,
      type: .quantityType(forIdentifier: .distanceWalkingRunning)!,
      startDate: beginningOfDay,
      endDate:endingOfDay
    ).compactMap { .init($0, unit: .distanceWalkingRunning) }
    
    let vo2Max: [QuantitySample] = try await querySample(
      healthKitStore: healthKitStore,
      type: .quantityType(forIdentifier: .vo2Max)!,
      startDate: beginningOfDay,
      endDate: endingOfDay
    ).compactMap { .init($0, unit: .vo2Max) }
    
    var copy = activity
    
    copy.basalEnergyBurned = basalEnergyBurned
    copy.steps = steps
    copy.floorsClimbed = floorsClimbed
    copy.distanceWalkingRunning = distanceWalkingRunning
    copy.vo2Max = vo2Max
    
    copies.append(copy)
  }
  
  let lastActivityDate = copies.lastDate()
  return (.init(activities: copies), lastActivityDate)
}

func handleWorkouts(
  healthKitStore: HKHealthStore,
  vitalStorage: VitalStorage,
  isBackgroundUpdating: Bool,
  startDate: Date = .dateAgo(days: 30),
  endDate: Date = .init()
) async throws -> (workoutPatch: VitalWorkoutPatch, anchors: [String: HKQueryAnchor]) {
  
  var anchors: [String: HKQueryAnchor] = [:]

  let workoutType = HKSampleType.workoutType()
  let payload = try await query(
    healthKitStore: healthKitStore,
    vitalStorage: vitalStorage,
    isBackgroundUpdating: isBackgroundUpdating,
    type: .workoutType(),
    startDate: startDate,
    endDate: endDate
  )
  
  let workouts = payload.sample.compactMap(VitalWorkoutPatch.Workout.init)
  anchors.setSafely(payload.anchor, key: String(describing: workoutType))
  
  var copies: [VitalWorkoutPatch.Workout] = []
  
  for workout in workouts {
    let heartRate: [QuantitySample] = try await querySample(
      healthKitStore: healthKitStore,
      type: .quantityType(forIdentifier: .heartRate)!,
      startDate: workout.startDate,
      endDate: workout.endDate
    ).compactMap { .init($0, unit: .heartRate) }
    
    let respiratoryRate: [QuantitySample] = try await querySample(
      healthKitStore: healthKitStore,
      type: .quantityType(forIdentifier: .respiratoryRate)!,
      startDate: workout.startDate,
      endDate: workout.endDate
    ).compactMap { .init($0, unit: .restingHeartRate) }
    
    
    var copy = workout
    copy.heartRate = heartRate
    copy.respiratoryRate = respiratoryRate
    
    copies.append(copy)
  }
  
  return (.init(workouts: copies), anchors)
}

func handleGlucose(
  healthKitStore: HKHealthStore,
  vitalStorage: VitalStorage,
  isBackgroundUpdating: Bool,
  startDate: Date = .dateAgo(days: 30),
  endDate: Date = .init()
) async throws -> (glucosePatch: VitalGlucosePatch, anchors: [String: HKQueryAnchor]) {
  
  let bloodGlucoseType = HKSampleType.quantityType(forIdentifier: .bloodGlucose)!
  let payload = try await query(
    healthKitStore: healthKitStore,
    vitalStorage: vitalStorage,
    isBackgroundUpdating: isBackgroundUpdating,
    type: bloodGlucoseType,
    startDate: startDate,
    endDate: endDate
  )
  
  var anchors: [String: HKQueryAnchor] = [:]
  let glucose: [QuantitySample] = payload.sample.compactMap { .init($0, unit: .glucose) }
  
  anchors.setSafely(payload.anchor, key: String(describing: bloodGlucoseType))
  return (.init(glucose: glucose), anchors)
}

private func query(
  healthKitStore: HKHealthStore,
  vitalStorage: VitalStorage? = nil,
  isBackgroundUpdating: Bool = false,
  type: HKSampleType,
  limit: Int = HKObjectQueryNoLimit,
  startDate: Date,
  endDate: Date
) async throws -> (sample: [HKSample], anchor: HKQueryAnchor?) {
  
  return try await withCheckedThrowingContinuation { continuation in
    
    let handler: AnchorQueryHandler = { (query, samples, deletedObject, newAnchor, error) in
      if let error = error {
        continuation.resume(with: .failure(error))
        return
      }
      
      continuation.resume(with: .success((samples ?? [], newAnchor)))
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
    
    if isBackgroundUpdating && limit == HKObjectQueryNoLimit {
      query.updateHandler = handler
    }
    
    healthKitStore.execute(query)
  }
}

private func querySample(
  healthKitStore: HKHealthStore,
  type: HKSampleType,
  startDate: Date,
  endDate: Date
) async throws -> [HKSample] {
  
  return try await withCheckedThrowingContinuation { continuation in
    
    let handler: SampleQueryHandler = { (query, samples, error) in
      if let error = error {
        continuation.resume(with: .failure(error))
        return
      }
      
      continuation.resume(with: .success(samples ?? []))
    }
    
    let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: [])
    let query = HKSampleQuery(
      sampleType: type,
      predicate: predicate,
      limit: HKObjectQueryNoLimit,
      sortDescriptors: [.init(key: "startDate", ascending: true)],
      resultsHandler: handler
    )
    
    healthKitStore.execute(query)
  }
}

// TODO: Think about how to deal with the continuation
//private func querySeries(
//  healthKitStore: HKHealthStore,
//  type: HKQuantityType,
//  startDate: Date,
//  endDate: Date
//) async throws -> [HKSample] {
//
//  return try await withCheckedThrowingContinuation { continuation in
//
//    let handler: SeriesSampleHandler = { (query, quantity, dateInterval, quantitySample, isFinished,  error) in
//      if let error = error {
//        continuation.resume(with: .failure(error))
//        return
//      }
//
//    }
//
//
//    let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: [])
//    let query = HKQuantitySeriesSampleQuery(quantityType: type, predicate: predicate, quantityHandler: handler)
//    query.includeSample = true
//
//    healthKitStore.execute(query)
//  }
//}


private func activityQuery(
  healthKitStore: HKHealthStore,
  isBackgroundUpdating: Bool = false,
  startDate: Date,
  endDate: Date
) async throws -> [HKActivitySummary] {
  
  return try await withCheckedThrowingContinuation { continuation in
    
    let handler: ActivityQueryHandler = { (query, activities, error) in
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
