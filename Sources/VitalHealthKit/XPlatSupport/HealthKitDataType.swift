import HealthKit

@_spi(VitalSDKCrossPlatformSupport)
public func decodeHealthKitDataTypeIdentifier(
  _ rawValue: String
) -> HKObjectType? {
  if rawValue.hasPrefix("HKQuantityType") {
    return HKQuantityType.quantityType(forIdentifier: .init(rawValue: rawValue))
  }
  if rawValue.hasPrefix("HKCategoryType") {
    return HKCategoryType.categoryType(forIdentifier: .init(rawValue: rawValue))
  }
  if rawValue.hasPrefix("HKCorrelationType") {
    return HKCorrelationType.correlationType(forIdentifier: .init(rawValue: rawValue))
  }
  if rawValue.hasPrefix("HKDocumentType") {
    return HKDocumentType.documentType(forIdentifier: .init(rawValue: rawValue))
  }
  if rawValue.hasPrefix("HKCharacteristicType") {
    return HKCharacteristicType.characteristicType(forIdentifier: .init(rawValue: rawValue))
  }
  if rawValue == HKDataTypeIdentifierHeartbeatSeries {
    return HKSeriesType.seriesType(forIdentifier: rawValue)
  }
  if rawValue == "HKWorkoutType" {
    return HKWorkoutType.workoutType()
  }
  if rawValue == "HKActivitySummaryType" {
    return HKActivitySummaryType.activitySummaryType()
  }
  if rawValue == "HKElectrocardiogramType" {
    return HKElectrocardiogramType.electrocardiogramType()
  }
  if rawValue == "HKAudiogramSampleType" {
    return HKAudiogramSampleType.audiogramSampleType()
  }
  if rawValue == "HKPrescriptionType" {
    if #available(iOS 16.0, *) {
      return HKPrescriptionType.visionPrescriptionType()
    }
  }
  if rawValue == "HKStateOfMindType" {
    if #available(iOS 18.0, *) {
      return HKStateOfMindType.stateOfMindType()
    }
  }
  if rawValue.hasPrefix("HKScoredAssessmentType") {
    if #available(iOS 18.0, *) {
      return HKScoredAssessmentType(.init(rawValue: rawValue))
    }
  }
  return nil
}
