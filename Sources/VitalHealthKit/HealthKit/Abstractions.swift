import HealthKit
import VitalCore

struct VitalHealthKitStore {
  var isHealthDataAvailable: () -> Bool
  
  var requestReadWriteAuthorization: ([VitalResource], [WritableVitalResource]) async throws -> Void
  
  var hasAskedForPermission: (VitalResource) -> Bool
  
  var toVitalResource: (HKSampleType) -> VitalResource
  
  var writeInput: (DataInput, Date, Date) async throws -> Void
  var readResource: (VitalResource, Date, Date, VitalHealthKitStorage) async throws -> (ProcessedResourceData, [StoredAnchor])
  
  var enableBackgroundDelivery: (HKObjectType, HKUpdateFrequency, @escaping (Bool, Error?) -> Void) -> Void
  var disableBackgroundDelivery: () async -> Void
  
  var execute: (HKObserverQuery) -> Void
  var stop: (HKObserverQuery) -> Void
}

extension VitalHealthKitStore {
  static func sampleTypeToVitalResource(
    hasAskedForPermission: ((VitalResource) -> Bool),
    type: HKSampleType
  ) -> VitalResource {
    switch type {
      case
        HKQuantityType.quantityType(forIdentifier: .bodyMass)!,
        HKQuantityType.quantityType(forIdentifier: .bodyFatPercentage)!:
        
        /// If the user has explicitly asked for Body permissions, then it's the resource is Body
        if hasAskedForPermission(.body) {
          return .body
        } else {
          /// If the user has given permissions to a single permission in the past (e.g. weight) we should
          /// treat it as such
          return type.toIndividualResource
        }
        
      case HKQuantityType.quantityType(forIdentifier: .height)!:
        return .profile
        
      case HKSampleType.workoutType():
        return .workout
        
      case HKSampleType.categoryType(forIdentifier: .sleepAnalysis):
        return .sleep
        
      case
        HKSampleType.quantityType(forIdentifier: .activeEnergyBurned)!,
        HKSampleType.quantityType(forIdentifier: .basalEnergyBurned)!,
        HKSampleType.quantityType(forIdentifier: .stepCount)!,
        HKSampleType.quantityType(forIdentifier: .flightsClimbed)!,
        HKSampleType.quantityType(forIdentifier: .distanceWalkingRunning)!,
        HKSampleType.quantityType(forIdentifier: .vo2Max)!:
        
        if hasAskedForPermission(.activity) {
          return .activity
        } else {
          return type.toIndividualResource
        }
        
      case HKSampleType.quantityType(forIdentifier: .bloodGlucose)!:
        return .vitals(.glucose)
        
      case
        HKSampleType.quantityType(forIdentifier: .bloodPressureSystolic)!,
        HKSampleType.quantityType(forIdentifier: .bloodPressureDiastolic)!:
        return .vitals(.bloodPressure)
        
      case
        HKSampleType.quantityType(forIdentifier: .heartRate)!:
        return .vitals(.hearthRate)
        
      case HKSampleType.quantityType(forIdentifier: .dietaryWater)!:
        return .nutrition(.water)
        
      case HKSampleType.quantityType(forIdentifier: .dietaryCaffeine)!:
        return .nutrition(.caffeine)
        
      default:
        fatalError("\(String(describing: self)) is not supported. This is a developer error")
    }
  }
  
  static var live: VitalHealthKitStore {
    let store = HKHealthStore()
    
    let hasAskedForPermission: (VitalResource) -> Bool = { resource in
      return toHealthKitTypes(resource: resource)
        .map { store.authorizationStatus(for: $0) != .notDetermined }
        .reduce(true, { $0 && $1})
    }
    
    let toVitalResource: (HKSampleType) -> VitalResource = { type in
      return sampleTypeToVitalResource(hasAskedForPermission: hasAskedForPermission, type: type)
    }
    
    return .init {
      HKHealthStore.isHealthDataAvailable()
    } requestReadWriteAuthorization: { readResources, writeResources in
      let readTypes = readResources.flatMap(toHealthKitTypes)
      let writeTypes: [HKSampleType] = writeResources
        .map(\.toResource)
        .flatMap(toHealthKitTypes)
        .compactMap { type in
          type as? HKSampleType
        }
      
      if #available(iOS 15.0, *) {
        try await store.requestAuthorization(toShare: Set(writeTypes), read: Set(readTypes))
      } else {
        try await store.__requestAuthorization(toShare: Set(writeTypes), read: Set(readTypes))
      }
      
    } hasAskedForPermission: { resource in
      return hasAskedForPermission(resource)
    } toVitalResource: { type in
      return toVitalResource(type)
    } writeInput: { (dataInput, startDate, endDate) in
      try await write(
        healthKitStore: store,
        dataInput: dataInput,
        startDate: startDate,
        endDate: endDate
      )
    } readResource: { (resource, startDate, endDate, storage) in
      try await read(
        resource: resource,
        healthKitStore: store,
        typeToResource: toVitalResource,
        vitalStorage: storage,
        startDate: startDate,
        endDate: endDate
      )
    } enableBackgroundDelivery: { (type, frequency, completion) in
      store.enableBackgroundDelivery(for: type, frequency: frequency, withCompletion: completion)
    } disableBackgroundDelivery: {
      try? await store.disableAllBackgroundDelivery()
    } execute: { query in
      store.execute(query)
    } stop: { query in
      store.stop(query)
    }
  }
  
  static var debug: VitalHealthKitStore {
    return .init {
      return true
    } requestReadWriteAuthorization: { _, _ in
      return
    } hasAskedForPermission: { _ in
      true
    } toVitalResource: { sampleType in
      return .sleep
    } writeInput: { (dataInput, startDate, endDate) in
      return
    } readResource: { _,_,_,_  in
      return (ProcessedResourceData.timeSeries(.glucose([])), [])
    } enableBackgroundDelivery: { _, _, _ in
      return
    } disableBackgroundDelivery: {
      return
    } execute: { _ in
      return
    } stop: { _ in
      return
    }
  }
}

struct VitalClientProtocol {
  var post: (ProcessedResourceData, TaggedPayload.Stage, Provider, TimeZone) async throws -> Void
  var checkConnectedSource: (Provider) async throws -> Void
}

extension VitalClientProtocol {
  static var live: VitalClientProtocol {
    .init { data, stage, provider, timeZone in
      switch data {
        case let .summary(summaryData):
          try await VitalClient.shared.summary.post(
            summaryData,
            stage: stage,
            provider: provider,
            timeZone: timeZone
          )
        case let .timeSeries(timeSeriesData):
          try await VitalClient.shared.timeSeries.post(
            timeSeriesData,
            stage: stage,
            provider: provider,
            timeZone: timeZone
          )
      }
    } checkConnectedSource: { provider in
      try await VitalClient.shared.checkConnectedSource(for: provider)
    }
  }
  
  static var debug: VitalClientProtocol {
    .init { _,_,_,_ in
      return ()
    } checkConnectedSource: { _ in
      return
    }
  }
}

struct StatisticsQueryDependencies {
  
  var executeStatisticalQuery: (Date, Date, @escaping StatisticInjectedsHandler) -> Void
  var executeSampleQuery: (Date, Date) async throws -> [HKSample]
  
  var isFirstTimeSycingType: () -> Bool
  var isLegacyType: () -> Bool
  
  var vitalAnchorsForType: () -> [VitalAnchor]
  var storedDate: () -> Date?
  var key: () -> String
  
  static var debug: StatisticsQueryDependencies {
    return .init { startDate, endDate, handler in
      fatalError()
    } executeSampleQuery: { _, _ in
      fatalError()
    } isFirstTimeSycingType: {
      fatalError()
    } isLegacyType: {
      fatalError()
    } vitalAnchorsForType: {
      fatalError()
    } storedDate: {
      fatalError()
    } key: {
      fatalError()
    }
  }
  
  static func live(
    healthKitStore: HKHealthStore,
    vitalStorage: VitalHealthKitStorage,
    type: HKQuantityType
  ) -> StatisticsQueryDependencies {
    let key = String(describing: type.self)
    
    return .init { startDate, endDate, handler in
      
      let predicate = HKQuery.predicateForSamples(
        withStart: startDate,
        end: endDate,
        options: [.strictStartDate]
      )
      
      let query = HKStatisticsCollectionQuery(
        quantityType: type,
        quantitySamplePredicate: predicate,
        options: [.cumulativeSum, .separateBySource],
        anchorDate: startDate,
        intervalComponents: .init(hour: 1)
      )
      
      let queryHandler: StatisticsHandler = { query, statistics, error in
        healthKitStore.stop(query)
        
        let values: [HKStatistics] = statistics?.statistics() ?? []
        let vitalStatistics = values.compactMap { statistics in
          VitalStatistics(statistics: statistics, type: type)
        }
        
        handler(vitalStatistics, error)
      }
      
      query.initialResultsHandler = queryHandler
      healthKitStore.execute(query)
      
    } executeSampleQuery: { startDate, endDate in
      try await querySample(healthKitStore: healthKitStore, type: type, startDate: startDate, endDate: endDate)
      
    } isFirstTimeSycingType: {
      return vitalStorage.isFirstTimeSycingType(for: key)
      
    } isLegacyType: {
      return vitalStorage.isLegacyType(for: key)
      
    } vitalAnchorsForType: {
      return vitalStorage.read(key: key)?.vitalAnchors ?? []
      
    } storedDate: {
      return vitalStorage.read(key: key)?.date
      
    } key: {
      return key
    }
  }
}
