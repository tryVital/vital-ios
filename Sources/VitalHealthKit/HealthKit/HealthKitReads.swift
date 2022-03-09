import HealthKit

func readWeight(from startDate: Date?, to endDate: Date?) {
  let healthStore = HKHealthStore()
  
    // first, we define the object type we want
  guard let sleepType = HKObjectType.quantityType(forIdentifier: .bodyMass) else {
    return
  }
  
    // we create a predicate to filter our data
  let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
  
    // I had a sortDescriptor to get the recent data first
  let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
  
    // we create our query with a block completion to execute
  let query = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sortDescriptor]) { (query, result, error) in
    if error != nil {
        // handle error
      return
    }
    
    if let result = result {
      
        // do something with those data
      result
        .compactMap({ $0 as? HKDiscreteQuantitySample })
        .forEach({ sample in
          
          print(sample)
        })
    }
  }
  
  healthStore.execute(query)
}

typealias QueryHandler = (HKAnchoredObjectQuery, [HKSample]?, [HKDeletedObject]?, HKQueryAnchor?, Error?) -> Void

struct VitalHealthKitQueryAnchors {
  var height: HKQueryAnchor?
}

var foo = VitalHealthKitQueryAnchors()

func readSleep(from startDate: Date?, to endDate: Date?) {
  
  let healthStore = HKHealthStore()
  let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
  
  guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
    return
  }
  
  let handler: QueryHandler = { (query, samples, deletedObject, newAnchor, error) in
  }
  
  let query = HKAnchoredObjectQuery(type: sleepType, predicate: predicate, anchor: nil, limit: HKObjectQueryNoLimit, resultsHandler: handler)
  query.updateHandler = handler
  
  
  healthStore.execute(query)
}


