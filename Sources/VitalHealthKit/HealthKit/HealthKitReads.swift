import HealthKit
import VitalCore

typealias SampleQueryHandler = (HKSampleQuery, [HKSample]?, Error?) -> Void
typealias AnchorQueryHandler = (HKAnchoredObjectQuery, [HKSample]?, [HKDeletedObject]?, HKQueryAnchor?, Error?) -> Void
typealias ActivityQueryHandler = (HKActivitySummaryQuery, [HKActivitySummary]?, Error?) -> Void

typealias SeriesSampleHandler = (HKQuantitySeriesSampleQuery, HKQuantity?, DateInterval?, HKQuantitySample?, Bool, Error?) -> Void


func handle(
  resource: VitalResource,
  store: HKHealthStore,
  vitalStorage: VitalStorage,
  startDate: Date,
  endDate: Date
) async throws -> (VitalNetworkClient.Summary.Resource, [StoredEntity]) {
  
  switch resource {
    case .profile:
      let profilePayload = try await handleProfile(
        healthKitStore: store
      )
      
      return (.profile(profilePayload), [])
      
    case .body:
      let payload = try await handleBody(
        healthKitStore: store,
        vitalStorage: vitalStorage,
        startDate: startDate,
        endDate: endDate
      )
            
      let entitiesToStore = payload.anchors.map { StoredEntity.anchor($0.key, $0.value) }
      return (.body(payload.bodyPatch), entitiesToStore)
      
    case .sleep:
      let payload = try await handleSleep(
        healthKitStore: store,
        vitalStorage: vitalStorage,
        startDate: startDate,
        endDate: endDate
      )
      
      let entitiesToStore = payload.anchors.map { StoredEntity.anchor($0.key, $0.value) }
      return (.sleep(payload.sleepPatch), entitiesToStore)
      
    case .activity:
      let payload = try await handleActivity(
        healthKitStore: store,
        vitalStorage: vitalStorage,
        startDate: startDate,
        endDate: endDate
      )
      
      let data = payload.lastActivityDate == nil ? [] : [StoredEntity.date(VitalStorage.activityKey, payload.lastActivityDate!)]
      return (.activity(payload.acitivtyPatch), data)
      
    case .workout:
      let payload = try await handleWorkouts(
        healthKitStore: store,
        vitalStorage: vitalStorage,
        startDate: startDate,
        endDate: endDate
      )
      
      let entitiesToStore = payload.anchors.map { StoredEntity.anchor($0.key, $0.value) }
      
      return (.workout(payload.workoutPatch), entitiesToStore)
      
    case .vitals(.glucose):
      let payload = try await handleGlucose(
        healthKitStore: store,
        vitalStorage: vitalStorage,
        startDate: startDate,
        endDate: endDate
      )
      
      let entitiesToStore = payload.anchors.map { StoredEntity.anchor($0.key, $0.value) }
      
      return (.glucose(payload.glucose), entitiesToStore)
  }
}

func handleProfile(
  healthKitStore: HKHealthStore
) async throws -> ProfilePatch {
  
  let sex = try healthKitStore.biologicalSex().biologicalSex
  let biologicalSex = ProfilePatch.BiologicalSex(healthKitSex: sex)
  
  var calendar = Calendar.current
  calendar.timeZone = TimeZone(secondsFromGMT: 0)!
  
  let components = try healthKitStore.dateOfBirthComponents()
  let dateOfBirth = calendar.date(from: components)

  
  let payload: [QuantitySample] = try await querySample(
    healthKitStore: healthKitStore,
    type: .quantityType(forIdentifier: .height)!,
    limit: 1,
    ascending: false
  ).compactMap { .init($0, unit: .height) }
  
  let height = payload.last.map { Int($0.value)}
  
  return .init(
    biologicalSex: biologicalSex,
    dateOfBirth: dateOfBirth,
    height: height
  )
}

func handleBody(
  healthKitStore: HKHealthStore,
  vitalStorage: VitalStorage,
  startDate: Date,
  endDate: Date
) async throws -> (bodyPatch: BodyPatch, anchors: [String: HKQueryAnchor]) {
  
  func queryQuantities(
    type: HKSampleType,
    unit: QuantitySample.Unit
  ) async throws -> (quantities: [QuantitySample], (key: String, anchor: HKQueryAnchor? )) {
    
    let payload = try await query(
      healthKitStore: healthKitStore,
      vitalStorage: vitalStorage,
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
  
  let (bodyMass, bodyMassAnchor) = try await queryQuantities(
    type: .quantityType(forIdentifier: .bodyMass)!,
    unit: .bodyMass
  )
  
  let (bodyFatPercentage, bodyFatPercentageAnchor) = try await queryQuantities(
    type: .quantityType(forIdentifier: .bodyFatPercentage)!,
    unit: .bodyFatPercentage
  )
  
  anchors.setSafely(bodyMassAnchor.anchor, key: bodyMassAnchor.key)
  anchors.setSafely(bodyFatPercentageAnchor.anchor, key: bodyFatPercentageAnchor.key)
  
  return (.init(
    bodyMass: bodyMass,
    bodyFatPercentage: bodyFatPercentage
  ),
          anchors
  )
}

func handleSleep(
  healthKitStore: HKHealthStore,
  vitalStorage: VitalStorage,
  startDate: Date,
  endDate: Date
) async throws -> (sleepPatch: SleepPatch, anchors: [String: HKQueryAnchor]) {
  
  var anchors: [String: HKQueryAnchor] = [:]
  let sleepType = HKSampleType.categoryType(forIdentifier: .sleepAnalysis)!
  
  let payload = try await query(
    healthKitStore: healthKitStore,
    vitalStorage: vitalStorage,
    type: sleepType,
    startDate: startDate,
    endDate: endDate
  )
  
  let sleeps = payload.sample.compactMap(SleepPatch.Sleep.init)
  anchors.setSafely(payload.anchor, key: String(describing: sleepType))
  
  var copies: [SleepPatch.Sleep] = []
  
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
  vitalStorage: VitalStorage,
  startDate: Date,
  endDate: Date
) async throws -> (acitivtyPatch: ActivityPatch, lastActivityDate: Date?) {
  
  let startDate = vitalStorage.read(key: VitalStorage.activityKey)?.date ?? startDate
  
  let activities = try await activityQuery(
    healthKitStore: healthKitStore,
    startDate: startDate,
    endDate: endDate
  ).compactMap(ActivityPatch.Activity.init)
  
  
  var copies: [ActivityPatch.Activity] = []
  
  for activity in activities {
    
    let dayStart = activity.date.dayStart
    let dayEnd = activity.date.dayEnd
    
    let basalEnergyBurned: [QuantitySample] = try await querySample(
      healthKitStore: healthKitStore,
      type: .quantityType(forIdentifier: .basalEnergyBurned)!,
      startDate: dayStart,
      endDate: dayEnd
    ).compactMap { .init($0, unit: .basalEnergyBurned) }
    
    let steps: [QuantitySample] = try await querySample(
      healthKitStore: healthKitStore,
      type: .quantityType(forIdentifier: .stepCount)!,
      startDate: dayStart,
      endDate: dayEnd
    ).compactMap { .init($0, unit: .steps) }
    
    let floorsClimbed: [QuantitySample] = try await querySample(
      healthKitStore: healthKitStore,
      type: .quantityType(forIdentifier: .flightsClimbed)!,
      startDate: dayStart,
      endDate: dayEnd
    ).compactMap { .init($0, unit: .floorsClimbed) }
    
    let distanceWalkingRunning: [QuantitySample] = try await querySample(
      healthKitStore: healthKitStore,
      type: .quantityType(forIdentifier: .distanceWalkingRunning)!,
      startDate: dayStart,
      endDate: dayEnd
    ).compactMap { .init($0, unit: .distanceWalkingRunning) }
    
    let vo2Max: [QuantitySample] = try await querySample(
      healthKitStore: healthKitStore,
      type: .quantityType(forIdentifier: .vo2Max)!,
      startDate: dayStart,
      endDate: dayEnd
    ).compactMap { .init($0, unit: .vo2Max) }
    
    var copy = activity
    
    copy.basalEnergyBurned = basalEnergyBurned
    copy.steps = steps
    copy.floorsClimbed = floorsClimbed
    copy.distanceWalkingRunning = distanceWalkingRunning
    copy.vo2Max = vo2Max
    
    copies.append(copy)
  }
  
  let lastActivityDate = copies.sorted { $0.date > $1.date }.first?.date
  return (.init(activities: copies), lastActivityDate)
}

func handleWorkouts(
  healthKitStore: HKHealthStore,
  vitalStorage: VitalStorage,
  startDate: Date,
  endDate: Date
) async throws -> (workoutPatch: WorkoutPatch, anchors: [String: HKQueryAnchor]) {
  
  var anchors: [String: HKQueryAnchor] = [:]
  
  let workoutType = HKSampleType.workoutType()
  let payload = try await query(
    healthKitStore: healthKitStore,
    vitalStorage: vitalStorage,
    type: .workoutType(),
    startDate: startDate,
    endDate: endDate
  )
  
  let workouts = payload.sample.compactMap(WorkoutPatch.Workout.init)
  anchors.setSafely(payload.anchor, key: String(describing: workoutType))
  
  var copies: [WorkoutPatch.Workout] = []
  
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
  startDate: Date,
  endDate: Date
) async throws -> (glucose: [QuantitySample], anchors: [String: HKQueryAnchor]) {
  
  let bloodGlucoseType = HKSampleType.quantityType(forIdentifier: .bloodGlucose)!
  let payload = try await query(
    healthKitStore: healthKitStore,
    vitalStorage: vitalStorage,
    type: bloodGlucoseType,
    startDate: startDate,
    endDate: endDate
  )
  
  var anchors: [String: HKQueryAnchor] = [:]
  let glucose: [QuantitySample] = payload.sample.compactMap { .init($0, unit: .glucose) }
  
  anchors.setSafely(payload.anchor, key: String(describing: bloodGlucoseType))
  return (glucose, anchors)
}

private func query(
  healthKitStore: HKHealthStore,
  vitalStorage: VitalStorage? = nil,
  type: HKSampleType,
  limit: Int = HKObjectQueryNoLimit,
  startDate: Date? = nil,
  endDate: Date? = nil
) async throws -> (sample: [HKSample], anchor: HKQueryAnchor?) {
  
  return try await withCheckedThrowingContinuation { continuation in
    
    let handler: AnchorQueryHandler = { (query, samples, deletedObject, newAnchor, error) in
      healthKitStore.stop(query)
      
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

