import HealthKit
import VitalCore

struct VitalHealthKitStore {
  var isHealthDataAvailable: () -> Bool
  var requestReadAuthorization: ([VitalResource]) async throws -> Void
  var hasAskedForPermission: (VitalResource) -> Bool
  var readData: (VitalResource, Date, Date, VitalStorage) async throws -> (PostResource, [StoredEntity])
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
      return (PostResource.vitals(.glucose([])), [])
    }
  }
}


struct VitalNetworkPostData {
  var post: (PostResource, TaggedPayload.Stage, Provider) async throws -> Void
}

extension VitalNetworkPostData {
  static var live: VitalNetworkPostData {
    .init { resource, stage, provider in
      try await VitalNetworkClient.shared.summary.post(resource: resource, stage: stage, provider: provider)
    }
  }
  
  static var debug: VitalNetworkPostData {
    .init { _,_,_ in
      return ()
    }
  }
}
