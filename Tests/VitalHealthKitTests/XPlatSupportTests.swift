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
      decodeHealthKitDataTypeIdentifier("HKWorkoutTypeIdentifier"),
      HKWorkoutType.workoutType()
    )
    XCTAssertEqual(
      decodeHealthKitDataTypeIdentifier("HKActivitySummaryTypeIdentifier"),
      HKActivitySummaryType.activitySummaryType()
    )
    XCTAssertEqual(
      decodeHealthKitDataTypeIdentifier("HKDataTypeIdentifierElectrocardiogram"),
      HKElectrocardiogramType.electrocardiogramType()
    )
    XCTAssertEqual(
      decodeHealthKitDataTypeIdentifier("HKDataTypeIdentifierAudiogram"),
      HKAudiogramSampleType.audiogramSampleType()
    )
    if #available(iOS 16.0, *) {
      XCTAssertEqual(
        decodeHealthKitDataTypeIdentifier("HKVisionPrescriptionTypeIdentifier"),
        HKPrescriptionType.visionPrescriptionType()
      )
    }
    if #available(iOS 18.0, *) {
      XCTAssertEqual(
        decodeHealthKitDataTypeIdentifier("HKDataTypeStateOfMind"),
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

  func testIdentifierRawValue() {
    XCTAssertEqual(
      "HKQuantityTypeIdentifierStepCount",
      HKQuantityType(.stepCount).identifier
    )
    XCTAssertEqual(
      "HKCategoryTypeIdentifierSleepAnalysis",
      HKCategoryType(.sleepAnalysis).identifier
    )
    XCTAssertEqual(
      "HKDataTypeIdentifierHeartbeatSeries",
      HKSeriesType.seriesType(forIdentifier: HKDataTypeIdentifierHeartbeatSeries)?.identifier
    )
    XCTAssertEqual(
      "HKCharacteristicTypeIdentifierWheelchairUse",
      HKCharacteristicType(.wheelchairUse).identifier
    )
    XCTAssertEqual(
      "HKCorrelationTypeIdentifierBloodPressure",
      HKCorrelationType(.bloodPressure).identifier
    )
    XCTAssertEqual(
      "HKDocumentTypeIdentifierCDA",
      HKDocumentType(.CDA).identifier
    )
    XCTAssertEqual(
      "HKWorkoutTypeIdentifier",
      HKWorkoutType.workoutType().identifier
    )
    XCTAssertEqual(
      "HKActivitySummaryTypeIdentifier",
      HKActivitySummaryType.activitySummaryType().identifier
    )
    XCTAssertEqual(
      "HKDataTypeIdentifierElectrocardiogram",
      HKElectrocardiogramType.electrocardiogramType().identifier
    )
    XCTAssertEqual(
      "HKDataTypeIdentifierAudiogram",
      HKAudiogramSampleType.audiogramSampleType().identifier
    )
    if #available(iOS 16.0, *) {
      XCTAssertEqual(
        "HKVisionPrescriptionTypeIdentifier",
        HKPrescriptionType.visionPrescriptionType().identifier
      )
    }
    if #available(iOS 18.0, *) {
      XCTAssertEqual(
        "HKDataTypeStateOfMind",
        HKStateOfMindType.stateOfMindType().identifier
      )
    }
    if #available(iOS 18.0, *) {
      XCTAssertEqual(
        "HKScoredAssessmentTypeIdentifierGAD7",
        HKScoredAssessmentType(.GAD7).identifier
      )
    }
  }
}

