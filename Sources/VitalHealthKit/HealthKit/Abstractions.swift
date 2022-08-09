import HealthKit
import VitalCore

struct VitalHealthKitStore {
  var isHealthDataAvailable: () -> Bool
  var requestReadAuthorization: ([VitalResource]) async throws -> Void
  var hasAskedForPermission: (VitalResource) -> Bool
  
  var toVitalResource: (HKSampleType) -> VitalResource
  
  var readResource: (VitalResource, Date, Date, VitalHealthKitStorage) async throws -> (PostResourceData, [StoredAnchor])

  var enableBackgroundDelivery: (HKObjectType, HKUpdateFrequency, @escaping (Bool, Error?) -> Void) -> Void
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
    
    return .init {
        HKHealthStore.isHealthDataAvailable()
      } requestReadAuthorization: { resources in
        let types = resources.flatMap(toHealthKitTypes)
        try await store.__requestAuthorization(toShare: [], read: Set(types))
      } hasAskedForPermission: { resource in
        return hasAskedForPermission(resource)
      } toVitalResource: { type in
        return sampleTypeToVitalResource(hasAskedForPermission: hasAskedForPermission, type: type)
      } readResource: { (resource, startDate, endDate, storage) in
        try await read(
          resource: resource,
          healthKitStore: store,
          vitalStorage: storage,
          startDate: startDate,
          endDate: endDate
        )
      } enableBackgroundDelivery: { (type, frequency, completion) in
        store.enableBackgroundDelivery(for: type, frequency: frequency, withCompletion: completion)
      } execute: { query in
        store.execute(query)
      } stop: { query in
        store.stop(query)
      }
  }
  
  static var debug: VitalHealthKitStore {
    return .init {
      return true
    } requestReadAuthorization: { _ in
      return
    } hasAskedForPermission: { _ in
      true
    } toVitalResource: { sampleType in
      return .sleep
    } readResource: { _,_,_,_  in
      return (PostResourceData.timeSeries(.glucose([])), [])
    } enableBackgroundDelivery: { _, _, _ in
      return
    } execute: { _ in
      return
    } stop: { _ in
      return
    }
  }
}

struct VitalClientProtocol {
  var post: (PostResourceData, TaggedPayload.Stage, Provider) async throws -> Void
  var checkConnectedSource: (Provider) async throws -> Void
}

extension VitalClientProtocol {
  static var live: VitalClientProtocol {
    .init { data, stage, provider in
      switch data {
        case let .summary(summaryData):
          try await VitalClient.shared.summary.post(summaryData, stage: stage, provider: provider)
        case let .timeSeries(timeSeriesData):
          try await VitalClient.shared.timeSeries.post(timeSeriesData, stage: stage, provider: provider)
      }
    } checkConnectedSource: { provider in
      try await VitalClient.shared.checkConnectedSource(for: provider)
    }
  }
  
  static var debug: VitalClientProtocol {
    .init { _,_,_ in
      return ()
    } checkConnectedSource: { _ in
      return
    }
  }
}
