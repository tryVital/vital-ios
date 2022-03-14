import HealthKit

typealias SampleQueryHandler = (HKAnchoredObjectQuery, [HKSample]?, [HKDeletedObject]?, HKQueryAnchor?, Error?) -> Void
typealias ActivityQueryHandler = (HKActivitySummaryQuery, [HKActivitySummary]?, Error?) -> Void


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
) async throws -> VitalBodyPatch {
  
  func queryQuantities(
    type: HKSampleType,
    unit: DiscreteQuantity.Unit
  ) async throws -> [DiscreteQuantity] {
    
    return try await query(
      healthKitStore: healthKitStore,
      anchorStorage: anchtorStorage,
      isBackgroundUpdating: isBackgroundUpdating,
      type: type,
      startDate: startDate,
      endDate: endDate
    )
      .compactMap {
        .init($0, unit: unit)
      }
  }
  
  let height = try await queryQuantities(
    type: .quantityType(forIdentifier: .height)!,
    unit: .height
  )
  
  let bodyMass = try await queryQuantities(
    type: .quantityType(forIdentifier: .bodyMass)!,
    unit: .bodyMass
  )
  
  let bodyFatPercentage = try await queryQuantities(
    type: .quantityType(forIdentifier: .bodyFatPercentage)!,
    unit: .bodyFatPercentage
  )
  
  return .init(
    height: height,
    bodyMass: bodyMass,
    bodyFatPercentage: bodyFatPercentage
  )
}

func handleSleep(
  healthKitStore: HKHealthStore,
  anchtorStorage: AnchorStorage,
  isBackgroundUpdating: Bool,
  startDate: Date = .dateAgo(days: 30),
  endDate: Date = .init()
) async throws -> VitalSleepPatch {

  let sleeps = try await query(
    healthKitStore: healthKitStore,
    anchorStorage: anchtorStorage,
    isBackgroundUpdating: isBackgroundUpdating,
    type: .categoryType(forIdentifier: .sleepAnalysis)!,
    startDate: startDate,
    endDate: endDate
  )
    .compactMap(VitalSleepPatch.Sleep.init)
  
  var copies: [VitalSleepPatch.Sleep] = []
  
  for sleep in sleeps {
    
    let heartRate: [DiscreteQuantity] = try await query(
      healthKitStore: healthKitStore,
      type: .quantityType(forIdentifier: .heartRate)!,
      startDate: sleep.startDate,
      endDate: sleep.endDate
    ).compactMap { .init($0, unit: .heartRate) }
    
    let hearRateVariability: [DiscreteQuantity] = try await query(
      healthKitStore: healthKitStore,
      type: .quantityType(forIdentifier: .heartRateVariabilitySDNN)!,
      startDate: sleep.startDate,
      endDate: sleep.endDate
    ).compactMap { .init($0, unit: .heartRateVariability) }
    
    let oxygenSaturation: [DiscreteQuantity] = try await query(
      healthKitStore: healthKitStore,
      type: .quantityType(forIdentifier: .oxygenSaturation)!,
      startDate: sleep.startDate,
      endDate: sleep.endDate
    ).compactMap { .init($0, unit: .heartRateVariability) }
    
    var copy = sleep
    copy.heartRate = heartRate
    copy.heartRateVariability = hearRateVariability
    copy.oxygenSaturation = oxygenSaturation
    
    copies.append(copy)
  }

  return .init(sleep: copies)
}

func handleActivity(
  healthKitStore: HKHealthStore,
  dateStorage: DateStorage
) async throws -> VitalActivityPatch {
  
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
    ).compactMap { .init($0, unit: .basalEnergyBurned) }
    
    let steps: [DiscreteQuantity] = try await query(
      healthKitStore: healthKitStore,
      type: .quantityType(forIdentifier: .stepCount)!,
      startDate: date.beginningOfDay,
      endDate: date.endingOfDay
    ).compactMap { .init($0, unit: .steps) }
    
    let floorsClimbed: [DiscreteQuantity] = try await query(
      healthKitStore: healthKitStore,
      type: .quantityType(forIdentifier: .flightsClimbed)!,
      startDate: date.beginningOfDay,
      endDate: date.endingOfDay
    ).compactMap { .init($0, unit: .floorsClimbed) }

    let distanceWalkingRunning: [DiscreteQuantity] = try await query(
      healthKitStore: healthKitStore,
      type: .quantityType(forIdentifier: .distanceWalkingRunning)!,
      startDate: date.beginningOfDay,
      endDate: date.endingOfDay
    ).compactMap { .init($0, unit: .distanceWalkingRunning) }
    
    let vo2Max: [DiscreteQuantity] = try await query(
      healthKitStore: healthKitStore,
      type: .quantityType(forIdentifier: .vo2Max)!,
      startDate: date.beginningOfDay,
      endDate: date.endingOfDay
    ).compactMap { .init($0, unit: .vo2Max) }

    var copy = activity

    copy.basalEnergyBurned = basalEnergyBurned
    copy.steps = steps
    copy.floorsClimbed = floorsClimbed
    copy.distanceWalkingRunning = distanceWalkingRunning
    copy.vo2Max = vo2Max
    
    copies.append(copy)
  }
  
  return .init(activities: copies)
}


private func query(
  healthKitStore: HKHealthStore,
  anchorStorage: AnchorStorage? = nil,
  isBackgroundUpdating: Bool = false,
  type: HKSampleType,
  limit: Int = HKObjectQueryNoLimit,
  startDate: Date,
  endDate: Date
) async throws -> [HKSample] {
  
  return try await withCheckedThrowingContinuation { continuation in
    
    let handler: SampleQueryHandler = { (query, samples, deletedObject, newAnchor, error) in
      if let error = error {
        continuation.resume(with: .failure(error))
        return
      }
      
      if let anchor = newAnchor {
        anchorStorage?.set(anchor, forKey: String(describing: type.self))
      }
      
      continuation.resume(with: .success(samples ?? []))
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
  dateStorage: DateStorage? = nil,
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

