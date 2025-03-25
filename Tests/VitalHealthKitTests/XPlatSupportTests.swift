import XCTest
import HealthKit

@testable @_spi(VitalSDKCrossPlatformSupport) import VitalHealthKit
@testable import VitalCore

@available(iOS 15.0, *)
class XPlatSupportTests: XCTestCase {

  func testIdentifier() {
    XCTAssertEqual(
      decodeHealthKitDataTypeIdentifier("HKQuantityTypeIdentifierStepCount"),
      HKQuantityType(.stepCount)
    )
    XCTAssertEqual(
      decodeHealthKitDataTypeIdentifier("HKCategoryTypeIdentifierSleepAnalysis"),
      HKCategoryType(.sleepAnalysis)
    )
    XCTAssertEqual(
      decodeHealthKitDataTypeIdentifier("HKDataTypeIdentifierHeartbeatSeries"),
      HKSeriesType.seriesType(forIdentifier: HKDataTypeIdentifierHeartbeatSeries)
    )
    XCTAssertEqual(
      decodeHealthKitDataTypeIdentifier("HKCharacteristicTypeIdentifierWheelchairUse"),
      HKCharacteristicType(.wheelchairUse)
    )
    XCTAssertEqual(
      decodeHealthKitDataTypeIdentifier("HKCorrelationTypeIdentifierBloodPressure"),
      HKCorrelationType(.bloodPressure)
    )
    XCTAssertEqual(
      decodeHealthKitDataTypeIdentifier("HKDocumentTypeIdentifierCDA"),
      HKDocumentType(.CDA)
    )
    XCTAssertEqual(
      decodeHealthKitDataTypeIdentifier("HKWorkoutType"),
      HKWorkoutType.workoutType()
    )
    XCTAssertEqual(
      decodeHealthKitDataTypeIdentifier("HKActivitySummaryType"),
      HKActivitySummaryType.activitySummaryType()
    )
    XCTAssertEqual(
      decodeHealthKitDataTypeIdentifier("HKElectrocardiogramType"),
      HKElectrocardiogramType.electrocardiogramType()
    )
    XCTAssertEqual(
      decodeHealthKitDataTypeIdentifier("HKAudiogramSampleType"),
      HKAudiogramSampleType.audiogramSampleType()
    )
    if #available(iOS 16.0, *) {
      XCTAssertEqual(
        decodeHealthKitDataTypeIdentifier("HKPrescriptionType"),
        HKPrescriptionType.visionPrescriptionType()
      )
    }
    if #available(iOS 18.0, *) {
      XCTAssertEqual(
        decodeHealthKitDataTypeIdentifier("HKStateOfMindType"),
        HKStateOfMindType.stateOfMindType()
      )
    }
    if #available(iOS 18.0, *) {
      XCTAssertEqual(
        decodeHealthKitDataTypeIdentifier("HKScoredAssessmentTypeIdentifierGAD7"),
        HKScoredAssessmentType(.GAD7)
      )
    }
  }
}

