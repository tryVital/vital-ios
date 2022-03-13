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
  
  func queryQuantities(type: HKSampleType, transformation: (HKQuantity) -> Double) async throws -> [DiscreteQuantity] {
    return try await query(
      healthKitStore: healthKitStore,
      anchorStorage: anchtorStorage,
      isBackgroundUpdating: isBackgroundUpdating,
      type: type,
      startDate: startDate,
      endDate: endDate
    )
      .compactMap { $0 as? HKDiscreteQuantitySample }
      .map {
        let value = transformation($0.quantity)
        return DiscreteQuantity(
          id: $0.uuid.uuidString,
          value: value,
          date: $0.startDate,
          sourceBundle: $0.sourceRevision.source.bundleIdentifier
        )
      }
  }
  
  let height = try await queryQuantities(
    type: .quantityType(forIdentifier: .height)!,
    transformation: { $0.doubleValue(for: .meterUnit(with: .centi))}
  )
  
  let bodyMass = try await queryQuantities(
    type: .quantityType(forIdentifier: .bodyMass)!,
    transformation: { $0.doubleValue(for: .gramUnit(with: .kilo))}
  )
  
  let bodyFacePercentage = try await queryQuantities(
    type: .quantityType(forIdentifier: .bodyFatPercentage)!,
    transformation: { $0.doubleValue(for: .percent())}
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
  
  
  let sleep = try await query(
    healthKitStore: healthKitStore,
    anchorStorage: anchtorStorage,
    isBackgroundUpdating: isBackgroundUpdating,
    type: .categoryType(forIdentifier: .sleepAnalysis)!,
    startDate: startDate,
    endDate: endDate
  )
  
  
  
  let heartRate = try await query(
    healthKitStore: healthKitStore,
    isBackgroundUpdating: false,
    type: .quantityType(forIdentifier: .heartRate)!,
    startDate: startDate,
    endDate: endDate
  )
  
  
  
  print("ads")
  return .init(sleep: [])
}


private func query(
  healthKitStore: HKHealthStore,
  anchorStorage: AnchorStorage? = nil,
  isBackgroundUpdating: Bool,
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

