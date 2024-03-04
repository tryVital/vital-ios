import XCTest
import VitalCore
@testable import VitalHealthKit
import HealthKit
import os

struct ExpectedError: Error {}

private class MockHealthStore: HKHealthStore {
  override func execute(_ query: HKQuery) {
    switch query {
    case let query as HKAnchoredObjectQuery:
      typealias CompletionHandler = @convention(block) (HKAnchoredObjectQuery, [HKSample]?, [HKDeletedObject]?, HKQueryAnchor?, Error?) -> Void
      let handler = unsafeBitCast(
        query.value(forKey: "completionHandler")! as AnyObject,
        to: CompletionHandler.self
      )
      handler(query, [], [], nil, nil)

    case let query as HKStatisticsCollectionQuery:
      let handler = query.initialResultsHandler!
      handler(query, nil, ExpectedError())

    case let query as HKSampleQuery:
      typealias ResultHandler = @convention(block) (HKSampleQuery, [HKSample]?, Error?) -> Void
      let handler = unsafeBitCast(
        query.value(forKey: "resultHandler")! as AnyObject,
        to: ResultHandler.self
      )
      handler(query, [], nil)

    default:
      fatalError("Unsupported query type: \(type(of: query))")
    }
  }

  override func biologicalSex() throws -> HKBiologicalSexObject {
    return HKBiologicalSexObject()
  }

  override func dateOfBirthComponents() throws -> DateComponents {
    return DateComponents(year: 1999, month: 1, day: 1)
  }
}

class SampleTypeTests: XCTestCase {

  @available(iOS 16.0, *)
  func test_observed_types_are_mappable_to_resources() {
    let success = self.expectation(description: "test_body")
    let thrownError = OSAllocatedUnfairLock<Error?>(initialState: nil)

    Task {
      do {
        for hasAskedForPermission in [true, false] {
          for sampleType in observedSampleTypes().flatMap({ $0 }) {
            let permission: (VitalResource) -> Bool = { _ in hasAskedForPermission }

            let resource = VitalHealthKitStore.sampleTypeToVitalResource(
              hasAskedForPermission: permission,
              type: sampleType
            )

            do {
              _ = try await read(
                resource: resource,
                healthKitStore: MockHealthStore(),
                typeToResource: {
                  VitalHealthKitStore.sampleTypeToVitalResource(
                    hasAskedForPermission: permission,
                    type: $0
                  )
                },
                vitalStorage: .init(storage: .debug),
                startDate: Date(),
                endDate: Date()
              )
            } catch let error {
              switch error {
              case is ExpectedError:
                continue
              default:
                throw error
              }
            }
          }
        }
        success.fulfill()
      } catch let error {
        thrownError.withLock { $0 = error }
      }
    }

    wait(for: [success], timeout: 3.0)
    XCTAssertNil(thrownError.withLock { $0 })
  }

  func test_all_quantity_sample_types_have_mapped_unit() async {
    for sampleType in VitalResource.all.flatMap(toHealthKitTypes(resource:)) {
      guard let sampleType = sampleType as? HKQuantityType else { continue }
      _ = sampleType.toHealthKitUnits
      _ = sampleType.toUnitStringRepresentation
    }
  }

}
