import HealthKit

typealias QueryHandler = (HKAnchoredObjectQuery, [HKSample]?, [HKDeletedObject]?, HKQueryAnchor?, Error?) -> Void


func query(
  healthKitStore: HKHealthStore,
  anchtorStorage: AnchorStorage,
  isBackgroundUpdating: Bool,
  type: HKObjectType,
  startDate: Date = .init(),
  endDate: Date = .dateAgo(days: 30)
) async throws -> [HKSample]? {
  
  return try await withCheckedThrowingContinuation { continuation in
    let predicate: NSPredicate
    let query: HKAnchoredObjectQuery
    
    let handler: QueryHandler = { (query, samples, deletedObject, newAnchor, error) in
      if let error = error {
        continuation.resume(with: .failure(error))
        return
      }
      
      if let anchor = newAnchor {
        anchtorStorage.set(anchor, forKey: String(describing: type.self))
      }
      
      continuation.resume(with: .success(samples))
    }
    
    switch type {
      case is HKSampleType:
        predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: [])
        
        query = HKAnchoredObjectQuery(
          type: type as! HKSampleType,
          predicate: predicate,
          anchor: nil,
          limit: HKObjectQueryNoLimit,
          resultsHandler: handler
        )
        
      default:
        fatalError("Not implemented")
    }
    
    
    if isBackgroundUpdating {
      query.updateHandler = handler
    }
    
    healthKitStore.execute(query)
  }
}

