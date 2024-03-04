import XCTest
import VitalCore
@testable import VitalHealthKit
import HealthKit

class SampleTypeTests: XCTestCase {

  func test_observed_types_are_mappable_to_resources() async {
    for sampleType in observedSampleTypes().flatMap({ $0 }) {
      _ = VitalHealthKitStore.sampleTypeToVitalResource(
        hasAskedForPermission: { _ in true },
        type: sampleType
      )
      _ = VitalHealthKitStore.sampleTypeToVitalResource(
        hasAskedForPermission: { _ in false },
        type: sampleType
      )
    }
  }

  func test_all_quantity_sample_types_have_mapped_unit() async {
    for sampleType in VitalResource.all.flatMap(toHealthKitTypes(resource:)) {
      guard let sampleType = sampleType as? HKQuantityType else { continue }
      _ = sampleType.toHealthKitUnits
      _ = sampleType.toUnitStringRepresentation
    }
  }

}
