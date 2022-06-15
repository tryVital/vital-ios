import HealthKit
import VitalCore

struct VitalHealthKitStore {
  var isHealthDataAvailable: () -> Bool
  var requestReadAuthorization: ([VitalResource]) async throws -> Void
  var hasAskedForPermission: (VitalResource) -> Bool
  
  var readResource: (VitalResource, Date, Date, VitalHealthKitStorage) async throws -> (PostResourceData, [StoredAnchor])
  var readSample: (HKSampleType, TaggedPayload.Stage, Date, Date, VitalHealthKitStorage) async throws -> (PostResourceData, [StoredAnchor])

  var enableBackgroundDelivery: (HKObjectType, HKUpdateFrequency, @escaping (Bool, Error?) -> Void) -> Void
  var execute: (HKObserverQuery) -> Void
}

extension VitalHealthKitStore {
  static var live: VitalHealthKitStore {
    let store = HKHealthStore()
    return .init {
        HKHealthStore.isHealthDataAvailable()
      } requestReadAuthorization: { resources in
        let types = resources.flatMap(toHealthKitTypes)
        try await store.__requestAuthorization(toShare: [], read: Set(types))
      } hasAskedForPermission: { resource in
        return toHealthKitTypes(resource: resource)
          .map { store.authorizationStatus(for: $0) != .notDetermined }
          .reduce(true, { $0 && $1})
      } readResource: { (resource, startDate, endDate, storage) in
        try await read(
          resource: resource,
          healthKitStore: store,
          vitalStorage: storage,
          startDate: startDate,
          endDate: endDate
        )
      } readSample: { (type, stage, startDate, endDate, storage) in
        try await read(
          type: type,
          stage: stage,
          healthKitStore: store,
          vitalStorage: storage,
          startDate: startDate,
          endDate: endDate
        )
      } enableBackgroundDelivery: { (type, frequency, completion) in
        store.enableBackgroundDelivery(for: type, frequency: frequency, withCompletion: completion)
      } execute: { query in
        store.execute(query)
      }
  }
  
  static var debug: VitalHealthKitStore {
    return .init {
      return true
    } requestReadAuthorization: { _ in
      return
    } hasAskedForPermission: { _ in
      true
    } readResource: { _,_,_,_  in
      return (PostResourceData.timeSeries(.glucose([])), [])
    } readSample: { _,_,_,_,_  in
      return (PostResourceData.timeSeries(.glucose([])), [])
    } enableBackgroundDelivery: { _, _, _ in
      return
    } execute: { _ in
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
