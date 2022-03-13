import HealthKit

typealias QueryHandler = (HKAnchoredObjectQuery, [HKSample]?, [HKDeletedObject]?, HKQueryAnchor?, Error?) -> Void


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
  
  let bodyFacePercentage = try await queryQuantities(
    type: .quantityType(forIdentifier: .bodyFatPercentage)!,
    unit: .bodyFatPercentage
  )
  
  return .init(height: height, bodyMass: bodyMass, bodyFatPercentage: bodyFacePercentage)
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
    anchorStorage: nil, //TODO: Fix this, testing reasons
    isBackgroundUpdating: isBackgroundUpdating,
    type: .categoryType(forIdentifier: .sleepAnalysis)!,
    startDate: startDate,
    endDate: endDate
  )
    .compactMap(VitalSleepPatch.Sleep.init)
  
  var modified: [VitalSleepPatch.Sleep] = []
  
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
    
    var copy = sleep
    copy.heartRate = heartRate
    copy.heartRateVariability = hearRateVariability
    
    modified.append(copy)
  }

  return .init(sleep: modified)
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
    
    let handler: QueryHandler = { (query, samples, deletedObject, newAnchor, error) in
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

