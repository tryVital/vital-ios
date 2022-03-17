import HealthKit

typealias SampleQueryHandler = (HKAnchoredObjectQuery, [HKSample]?, [HKDeletedObject]?, HKQueryAnchor?, Error?) -> Void
typealias ActivityQueryHandler = (HKActivitySummaryQuery, [HKActivitySummary]?, Error?) -> Void


func handle(
  domain: Domain,
  store: HKHealthStore,
  anchorStorage: AnchorStorage,
  dateStorage: DateStorage,
  isBackgroundUpdating: Bool,
  startDate: Date = .dateAgo(days: 30),
  endDate: Date = .init()
) async throws -> (AnyEncodable, [EntityToStore]) {

  switch domain {
    case .profile:
      let profilePayload = try await handleProfile(
        healthKitStore: store,
        anchtorStorage: anchorStorage
      ).eraseToAnyEncodable()
      
      return (profilePayload, [])
      
    case .body:
      let payload = try await handleBody(
        healthKitStore: store,
        anchtorStorage: anchorStorage,
        isBackgroundUpdating: isBackgroundUpdating
      )
        
      let body = payload.bodyPatch.eraseToAnyEncodable()
      let entitiesToStore = payload.anchors.map { EntityToStore.anchor($0.key, $0.value) }
      
      return (body, entitiesToStore)
      
    case .sleep:
      let payload = try await handleSleep(
        healthKitStore: store,
        anchtorStorage: anchorStorage,
        isBackgroundUpdating: isBackgroundUpdating
      )
        
      let sleep = payload.sleepPatch.eraseToAnyEncodable()
      let entitiesToStore = payload.anchors.map { EntityToStore.anchor($0.key, $0.value) }

      return (sleep, entitiesToStore)
      
    case .activity:
      let payload = try await handleActivity(
        healthKitStore: store,
        dateStorage: dateStorage
      )
      
      let activity = payload.acitivtyPatch.eraseToAnyEncodable()
      let data = payload.lastActivityDate == nil ? [] : [EntityToStore.date(payload.lastActivityDate!)]
      
      return (activity, data)
      
    case .workout:
      let payload = try await handleWorkouts(
        healthKitStore: store,
        anchorStorage: anchorStorage,
        isBackgroundUpdating: isBackgroundUpdating
      )
        
      let workout = payload.workoutPatch.eraseToAnyEncodable()
      let entitiesToStore = payload.anchors.map { EntityToStore.anchor($0.key, $0.value) }

      return (workout, entitiesToStore)
      
    case .vitals(.glucose):
      let payload = try await handleGlucose(
        healthKitStore: store,
        anchorStorage: anchorStorage,
        isBackgroundUpdating: isBackgroundUpdating
      )
        
      let glucose = payload.glucosePatch.eraseToAnyEncodable()
      let entitiesToStore = payload.anchors.map { EntityToStore.anchor($0.key, $0.value) }

      return (glucose, entitiesToStore)
  }
}

func handleProfile(
  healthKitStore: HKHealthStore,
  anchtorStorage: AnchorStorage
) async throws -> VitalProfilePatch {
  
  let sex = try healthKitStore.biologicalSex().biologicalSex
  let biologicalSex = VitalProfilePatch.BiologicalSex(healthKitSex: sex)
  
  let dateOfBirth = try healthKitStore.dateOfBirthComponents().date
  
  return .init(biologicalSex: biologicalSex, dateOfBirth: dateOfBirth)
}

func handleBody(
  healthKitStore: HKHealthStore,
  anchtorStorage: AnchorStorage,
  isBackgroundUpdating: Bool,
  startDate: Date = .dateAgo(days: 30),
  endDate: Date = .init()
) async throws -> (bodyPatch: VitalBodyPatch, anchors: [String: HKQueryAnchor]) {
  
  func queryQuantities(
    type: HKSampleType,
    unit: DiscreteQuantity.Unit
  ) async throws -> (quantities: [DiscreteQuantity], (key: String, anchor: HKQueryAnchor? )) {
    
    let payload = try await query(
      healthKitStore: healthKitStore,
      anchorStorage: anchtorStorage,
      isBackgroundUpdating: isBackgroundUpdating,
      type: type,
      startDate: startDate,
      endDate: endDate
    )
  
    let quantities: [DiscreteQuantity] = payload.sample.compactMap {
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
  anchtorStorage: AnchorStorage,
  isBackgroundUpdating: Bool,
  startDate: Date = .dateAgo(days: 30),
  endDate: Date = .init()
) async throws -> (sleepPatch: VitalSleepPatch, anchors: [String: HKQueryAnchor]) {
  
  var anchors: [String: HKQueryAnchor] = [:]
  let sleepType = HKSampleType.categoryType(forIdentifier: .sleepAnalysis)!

  let payload = try await query(
    healthKitStore: healthKitStore,
    anchorStorage: anchtorStorage,
    isBackgroundUpdating: isBackgroundUpdating,
    type: sleepType,
    startDate: startDate,
    endDate: endDate
  )
  
  let sleeps = payload.sample.compactMap(VitalSleepPatch.Sleep.init)
  anchors.setSafely(payload.anchor, key: String(describing: sleepType))

  var copies: [VitalSleepPatch.Sleep] = []
  
  for sleep in sleeps {
    
    let heartRate: [DiscreteQuantity] = try await query(
      healthKitStore: healthKitStore,
      type: .quantityType(forIdentifier: .heartRate)!,
      startDate: sleep.startDate,
      endDate: sleep.endDate
    ).sample.compactMap { .init($0, unit: .heartRate) }
    
    let hearRateVariability: [DiscreteQuantity] = try await query(
      healthKitStore: healthKitStore,
      type: .quantityType(forIdentifier: .heartRateVariabilitySDNN)!,
      startDate: sleep.startDate,
      endDate: sleep.endDate
    ).sample.compactMap { .init($0, unit: .heartRateVariability) }
    
    let oxygenSaturation: [DiscreteQuantity] = try await query(
      healthKitStore: healthKitStore,
      type: .quantityType(forIdentifier: .oxygenSaturation)!,
      startDate: sleep.startDate,
      endDate: sleep.endDate
    ).sample.compactMap { .init($0, unit: .oxygenSaturation) }
    
    let restingHeartRate: [DiscreteQuantity] = try await query(
      healthKitStore: healthKitStore,
      type: .quantityType(forIdentifier: .restingHeartRate)!,
      startDate: sleep.startDate,
      endDate: sleep.endDate
    ).sample.compactMap { .init($0, unit: .restingHeartRate) }
    
    let respiratoryRate: [DiscreteQuantity] = try await query(
      healthKitStore: healthKitStore,
      type: .quantityType(forIdentifier: .respiratoryRate)!,
      startDate: sleep.startDate,
      endDate: sleep.endDate
    ).sample.compactMap { .init($0, unit: .restingHeartRate) }
    
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
  dateStorage: DateStorage
) async throws -> (acitivtyPatch: VitalActivityPatch, lastActivityDate: Date?) {
  
  let startDate = dateStorage.read() ?? .dateAgo(days: 30)
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
    
    let basalEnergyBurned: [DiscreteQuantity] = try await query(
      healthKitStore: healthKitStore,
      type: .quantityType(forIdentifier: .basalEnergyBurned)!,
      startDate: date.beginningOfDay,
      endDate: date.endingOfDay
    ).sample.compactMap { .init($0, unit: .basalEnergyBurned) }
    
    let steps: [DiscreteQuantity] = try await query(
      healthKitStore: healthKitStore,
      type: .quantityType(forIdentifier: .stepCount)!,
      startDate: date.beginningOfDay,
      endDate: date.endingOfDay
    ).sample.compactMap { .init($0, unit: .steps) }
    
    let floorsClimbed: [DiscreteQuantity] = try await query(
      healthKitStore: healthKitStore,
      type: .quantityType(forIdentifier: .flightsClimbed)!,
      startDate: date.beginningOfDay,
      endDate: date.endingOfDay
    ).sample.compactMap { .init($0, unit: .floorsClimbed) }
    
    let distanceWalkingRunning: [DiscreteQuantity] = try await query(
      healthKitStore: healthKitStore,
      type: .quantityType(forIdentifier: .distanceWalkingRunning)!,
      startDate: date.beginningOfDay,
      endDate: date.endingOfDay
    ).sample.compactMap { .init($0, unit: .distanceWalkingRunning) }
    
    let vo2Max: [DiscreteQuantity] = try await query(
      healthKitStore: healthKitStore,
      type: .quantityType(forIdentifier: .vo2Max)!,
      startDate: date.beginningOfDay,
      endDate: date.endingOfDay
    ).sample.compactMap { .init($0, unit: .vo2Max) }
    
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
  anchorStorage: AnchorStorage,
  isBackgroundUpdating: Bool,
  startDate: Date = .dateAgo(days: 30),
  endDate: Date = .init()
) async throws -> (workoutPatch: VitalWorkoutPatch, anchors: [String: HKQueryAnchor]) {
  
  var anchors: [String: HKQueryAnchor] = [:]

  let workoutType = HKSampleType.workoutType()
  let payload = try await query(
    healthKitStore: healthKitStore,
    anchorStorage: anchorStorage,
    isBackgroundUpdating: isBackgroundUpdating,
    type: .workoutType(),
    startDate: startDate,
    endDate: endDate
  )
  
  let workouts = payload.sample.compactMap(VitalWorkoutPatch.Workout.init)
  anchors.setSafely(payload.anchor, key: String(describing: workoutType))
  
  var copies: [VitalWorkoutPatch.Workout] = []
  
  for workout in workouts {
    let heartRate: [DiscreteQuantity] = try await query(
      healthKitStore: healthKitStore,
      type: .quantityType(forIdentifier: .heartRate)!,
      startDate: workout.startDate,
      endDate: workout.endDate
    ).sample.compactMap { .init($0, unit: .heartRate) }
    
    let respiratoryRate: [DiscreteQuantity] = try await query(
      healthKitStore: healthKitStore,
      type: .quantityType(forIdentifier: .respiratoryRate)!,
      startDate: workout.startDate,
      endDate: workout.endDate
    ).sample.compactMap { .init($0, unit: .restingHeartRate) }
    
    
    var copy = workout
    copy.heartRate = heartRate
    copy.respiratoryRate = respiratoryRate
    
    copies.append(copy)
  }
  
  return (.init(workouts: copies), anchors)
}

func handleGlucose(
  healthKitStore: HKHealthStore,
  anchorStorage: AnchorStorage,
  isBackgroundUpdating: Bool,
  startDate: Date = .dateAgo(days: 30),
  endDate: Date = .init()
) async throws -> (glucosePatch: VitalGlucosePatch, anchors: [String: HKQueryAnchor]) {
  
  let bloodGlucoseType = HKSampleType.quantityType(forIdentifier: .bloodGlucose)!
  let payload = try await query(
    healthKitStore: healthKitStore,
    anchorStorage: anchorStorage,
    isBackgroundUpdating: isBackgroundUpdating,
    type: bloodGlucoseType,
    startDate: startDate,
    endDate: endDate
  )
  
  var anchors: [String: HKQueryAnchor] = [:]
  let glucose: [DiscreteQuantity] = payload.sample.compactMap { .init($0, unit: .glucose) }
  
  anchors.setSafely(payload.anchor, key: String(describing: bloodGlucoseType))
  return (.init(glucose: glucose), anchors)
}

private func query(
  healthKitStore: HKHealthStore,
  anchorStorage: AnchorStorage? = nil,
  isBackgroundUpdating: Bool = false,
  type: HKSampleType,
  limit: Int = HKObjectQueryNoLimit,
  startDate: Date,
  endDate: Date
) async throws -> (sample: [HKSample], anchor: HKQueryAnchor?) {
  
  return try await withCheckedThrowingContinuation { continuation in
    
    let handler: SampleQueryHandler = { (query, samples, deletedObject, newAnchor, error) in
      if let error = error {
        continuation.resume(with: .failure(error))
        return
      }
      
      continuation.resume(with: .success((samples ?? [], newAnchor)))
    }
    
    let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: [])
    let anchor = anchorStorage?.read(key: String(describing: type.self))
    
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
