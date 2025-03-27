import HealthKit
@_spi(VitalSDKInternals) import VitalCore
@testable import VitalHealthKit
import XCTest

class VitalResourceTests: XCTestCase {

  func test_hearthRate_remapped_to_heartRate() async {
    // XCTAssertEqual(VitalResource.vitals(.hearthRate), VitalResource.vitals(.heartRate))

    VitalBackStorage.live.clean()
    XCTAssertFalse(VitalBackStorage.live.isResourceFlagged(.vitals(.heartRate)))

    UserDefaults(suiteName: "tryVital")!.set(true, forKey: "vitals(VitalCore.VitalResource.Vitals.hearthRate)")
    XCTAssertTrue(VitalBackStorage.live.isResourceFlagged(.vitals(.heartRate)))
    // XCTAssertTrue(VitalBackStorage.live.isResourceFlagged(.vitals(.hearthRate)))

    UserDefaults(suiteName: "tryVital")!.set(nil, forKey: "vitals(VitalCore.VitalResource.Vitals.hearthRate)")
    XCTAssertFalse(VitalBackStorage.live.isResourceFlagged(.vitals(.heartRate)))
    // XCTAssertFalse(VitalBackStorage.live.isResourceFlagged(.vitals(.hearthRate)))

    VitalBackStorage.live.flagResource(.vitals(.heartRate))
    XCTAssertTrue(UserDefaults(suiteName: "tryVital")!.bool(forKey: "vitals(VitalCore.VitalResource.Vitals.heartRate)"))
    XCTAssertTrue(VitalBackStorage.live.isResourceFlagged(.vitals(.heartRate)))
    // XCTAssertTrue(VitalBackStorage.live.isResourceFlagged(.vitals(.hearthRate)))
  }

  func test_priority_of_remapped_resources_should_be_Int_max() {
    var invalid = Set<VitalResource>()

    for resource in VitalResource.all {
      let remapped = VitalHealthKitStore.remapResource(resource)
      if remapped.wrapped != resource, resource.priority != Int.max {
        invalid.insert(resource)
      }
    }

    XCTAssertEqual(invalid, [])
  }

}
