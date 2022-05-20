import HealthKit
import VitalCore

struct VitalHealthKitStore {
  var isHealthDataAvailable: () -> Bool
  var requestReadAuthorization: ([VitalResource]) async throws -> Void
  var hasAskedForPermission: (VitalResource) -> Bool
  var readData: (VitalResource, Date, Date, VitalStorage) async throws -> (PostResourceData, [StoredEntity])
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
      } readData: { (resource, startDate, endDate, storage) in
        try await handle(
          resource: resource,
          store: store,
          vitalStorage: storage,
          startDate: startDate,
          endDate: endDate
        )
      }
  }
  
  static var debug: VitalHealthKitStore {
    return .init {
      return true
    } requestReadAuthorization: { _ in
      return
    } hasAskedForPermission: { _ in
      true
    } readData: { _,_,_,_  in
      return (PostResourceData.timeSeries(.glucose([])), [])
    }
  }
}


struct VitalNetworkPostData {
  var post: (PostResourceData, TaggedPayload.Stage, Provider) async throws -> Void
}

extension VitalNetworkPostData {
  static var live: VitalNetworkPostData {
    .init { data, stage, provider in
      switch data {
        case let .summary(summaryData):
          try await VitalClient.shared.summary.post(summaryData, stage: stage, provider: provider)
        case let .timeSeries(timeSeriesData):
          try await VitalClient.shared.timeSeries.post(timeSeriesData, stage: stage, provider: provider)
      }
    }
  }
  
  static var debug: VitalNetworkPostData {
    .init { _,_,_ in
      return ()
    }
  }
}
