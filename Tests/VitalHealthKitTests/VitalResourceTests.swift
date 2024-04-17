import HealthKit
import VitalCore
@testable import VitalHealthKit
import XCTest

class VitalResourceTests: XCTestCase {

  func test_hearthRate_remapped_to_heartRate() async {
    XCTAssertEqual(VitalResource.vitals(.hearthRate), VitalResource.vitals(.heartRate))

    VitalBackStorage.live.clean()
    XCTAssertFalse(VitalBackStorage.live.isResourceFlagged(.vitals(.heartRate)))

    UserDefaults(suiteName: "tryVital")!.set(true, forKey: "vitals(VitalCore.VitalResource.Vitals.hearthRate)")
    XCTAssertTrue(VitalBackStorage.live.isResourceFlagged(.vitals(.heartRate)))
    XCTAssertTrue(VitalBackStorage.live.isResourceFlagged(.vitals(.hearthRate)))

    UserDefaults(suiteName: "tryVital")!.set(nil, forKey: "vitals(VitalCore.VitalResource.Vitals.hearthRate)")
    XCTAssertFalse(VitalBackStorage.live.isResourceFlagged(.vitals(.heartRate)))
    XCTAssertFalse(VitalBackStorage.live.isResourceFlagged(.vitals(.hearthRate)))

    VitalBackStorage.live.flagResource(.vitals(.heartRate))
    XCTAssertTrue(UserDefaults(suiteName: "tryVital")!.bool(forKey: "vitals(VitalCore.VitalResource.Vitals.heartRate)"))
    XCTAssertTrue(VitalBackStorage.live.isResourceFlagged(.vitals(.heartRate)))
    XCTAssertTrue(VitalBackStorage.live.isResourceFlagged(.vitals(.hearthRate)))
  }

}
