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
      DispatchQueue.global().async {
        handler(query, nil, nil, nil, ExpectedError())
      }

    case let query as HKStatisticsCollectionQuery:
      let handler = query.initialResultsHandler!

      DispatchQueue.global().async {
        handler(query, nil, ExpectedError())
      }

    case let query as HKSampleQuery:
      typealias ResultHandler = @convention(block) (HKSampleQuery, [HKSample]?, Error?) -> Void
      let handler = unsafeBitCast(
        query.value(forKey: "resultHandler")! as AnyObject,
        to: ResultHandler.self
      )
      DispatchQueue.global().async {
        handler(query, nil, ExpectedError())
      }

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
  func test_observed_types_are_mappable_to_resources() async throws {
    let resources = observedSampleTypes()
      .flatMap({ $0 })
      .flatMap(VitalHealthKitStore.sampleTypeToVitalResource)

    for resource in resources {
      do {
        _ = try await read(
          resource: VitalHealthKitStore.remapResource(resource),
          healthKitStore: MockHealthStore(),
          vitalStorage: VitalHealthKitStorage(storage: .debug),
          instruction: SyncInstruction(stage: .daily, query: Date() ..< Date()),
          options: ReadOptions()
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

  func test_all_quantity_sample_types_have_mapped_unit() async {
    let allQuantityTypes = VitalResource.all
      .map(toHealthKitTypes(resource:))
      .flatMap(\.allObjectTypes)
      .compactMap { $0 as? HKQuantityType }

    for sampleType in allQuantityTypes {
      _ = QuantityUnit(.init(rawValue: sampleType.identifier))
    }
  }
  
  func test_all_quantity_units_are_compatible_with_the_associated_sample_type() throws {
    for (identifier, unit) in QuantityUnit.vitalStandardUnits {
      let qt = try XCTUnwrap(HKQuantityType.quantityType(forIdentifier: identifier))
      XCTAssertTrue(qt.is(compatibleWith: unit), "\(identifier) is incompatible with \(unit)")
    }
  }

  @available(iOS 15.0, *)
  func test_HealthKitObjectTypeRequirements_singleObjectType() {
    let requirements = HealthKitObjectTypeRequirements(
      required: [HKQuantityType(.appleExerciseTime)],
      optional: [],
      supplementary: []
    )

    // required[0] has been asked
    XCTAssertTrue(requirements.isResourceActive { _ in true })

    // required[0] has not been asked
    XCTAssertFalse(requirements.isResourceActive { _ in false })
  }

  @available(iOS 15.0, *)
  func test_HealthKitObjectTypeRequirements_multipleRequiredObjectTypes() {
    let requirements = HealthKitObjectTypeRequirements(
      required: [
        HKQuantityType(.appleExerciseTime),
        HKQuantityType(.appleMoveTime),
        HKQuantityType(.appleStandTime),
      ],
      optional: [],
      supplementary: []
    )

    // All asked
    XCTAssertTrue(requirements.isResourceActive { _ in true })

    // All asked, except for .appleStandTime
    XCTAssertFalse(requirements.isResourceActive { type in type != HKQuantityType(.appleStandTime) })

    // All have not been asked
    XCTAssertFalse(requirements.isResourceActive { _ in false })
  }

  @available(iOS 15.0, *)
  func test_HealthKitObjectTypeRequirements_SomeRequiredSomeOptionalTypes() {
    let requirements = HealthKitObjectTypeRequirements(
      required: [
        HKQuantityType(.appleExerciseTime),
        HKQuantityType(.appleMoveTime),
      ],
      optional: [
        HKQuantityType(.appleStandTime),
      ],
      supplementary: []
    )

    // All asked
    XCTAssertTrue(requirements.isResourceActive { _ in true })

    // Only appleExerciseTime has been asked
    XCTAssertFalse(requirements.isResourceActive { type in type == HKQuantityType(.appleExerciseTime) })

    // All except appleStandTime have been asked
    XCTAssertTrue(requirements.isResourceActive { type in type != HKQuantityType(.appleStandTime) })

    // All have not been asked
    XCTAssertFalse(requirements.isResourceActive { _ in false })
  }

  @available(iOS 15.0, *)
  func test_HealthKitObjectTypeRequirements_noRequiredMultipleOptionalTypes() {
    let requirements = HealthKitObjectTypeRequirements(
      required: [],
      optional: [
        HKQuantityType(.appleExerciseTime),
        HKQuantityType(.appleMoveTime),
        HKQuantityType(.appleStandTime),
      ],
      supplementary: []
    )

    // All asked
    XCTAssertTrue(requirements.isResourceActive { _ in true })

    // Only .appleStandTime has been asked
    XCTAssertTrue(requirements.isResourceActive { type in type == HKQuantityType(.appleStandTime) })

    // All have not been asked
    XCTAssertFalse(requirements.isResourceActive { _ in false })
  }

  @available(iOS 15.0, *)
  func test_HealthKitObjectTypeRequirements_empty() {
    let requirements = HealthKitObjectTypeRequirements(
      required: [],
      optional: [],
      supplementary: []
    )

    XCTAssertFalse(requirements.isResourceActive { _ in true })
    XCTAssertFalse(requirements.isResourceActive { _ in false })
  }


  @available(iOS 15.0, *)
  func test_HealthKitObjectTypeRequirements_does_not_overlap() throws {
    var claimedObjectTypes = Set<HKObjectType>()

    for resource in VitalResource.all {
      let requirements = toHealthKitTypes(resource: resource)

      let isNonoverlapping = requirements.required.intersection(claimedObjectTypes).isEmpty

      XCTAssertTrue(isNonoverlapping, "\(resource.logDescription) overlaps with another VitalResource.")

      // NOTE: A VitalResource can declare `requirements.optional` or `requirements.supplementary`
      // that overlaps with other resource.
      claimedObjectTypes.formUnion(requirements.required)
    }
  }
}
