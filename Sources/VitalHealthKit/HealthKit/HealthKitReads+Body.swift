import VitalCore
import HealthKit

func calculateBodySummaryWorkingRangeUsingAnchoredQuery(
  healthKitStore: HKHealthStore,
  vitalStorage: AnchorStorage,
  instruction: SyncInstruction,
  in calendar: GregorianCalendar
) async throws -> (ClosedRange<GregorianCalendar.FloatingDate>?, [StoredAnchor]) {
  @Sendable func queryNewSampleDates(_ type: HKQuantityTypeIdentifier) async throws -> ([GregorianCalendar.FloatingDate], StoredAnchor?) {
    return try await anchoredQuery(
      healthKitStore: healthKitStore,
      vitalStorage: vitalStorage,
      type: HKQuantityType.quantityType(forIdentifier: type)!,
      sampleClass: HKQuantitySample.self,
      unit: QuantityUnit(type),
      limit: 0,
      startDate: instruction.query.lowerBound,
      endDate: instruction.query.upperBound,
      transform: { sample, _ in
        if let zoneId = sample.metadata?[HKMetadataKeyTimeZone] as? String, let zone = TimeZone(identifier: zoneId) {
          GregorianCalendar(timeZone: zone).floatingDate(of: sample.startDate)
        } else {
          calendar.floatingDate(of: sample.startDate)
        }
      }
    )
  }

  async let _bodyMass = queryNewSampleDates(.bodyMass)
  async let _bodyFatPercentage = queryNewSampleDates(.bodyFatPercentage)
  async let _bodyMassIndex = queryNewSampleDates(.bodyMassIndex)
  async let _waistCircumference = queryNewSampleDates(.waistCircumference)
  async let _leanBodyMass = queryNewSampleDates(.leanBodyMass)

  let (dates0, anchor0) = try await _bodyMass
  let (dates1, anchor1) = try await _bodyFatPercentage
  let (dates2, anchor2) = try await _bodyMassIndex
  let (dates3, anchor3) = try await _waistCircumference
  let (dates4, anchor4) = try await _leanBodyMass

  let anchors = [anchor0, anchor1, anchor2, anchor3, anchor4].compactMap { $0 }
  let minDate = [dates0, dates1, dates2, dates3, dates4].lazy.flatMap { $0 }.min()
  let maxDate = [dates0, dates1, dates2, dates3, dates4].lazy.flatMap { $0 }.max()

  if let minDate = minDate, let maxDate = maxDate {
    return (minDate ... maxDate, anchors)
  } else {
    return (nil, anchors)
  }
}

func queryBodySummaries(
  healthKitStore: HKHealthStore,
  start: GregorianCalendar.FloatingDate,
  end: GregorianCalendar.FloatingDate,
  in calendar: GregorianCalendar
) async throws -> BodyPatch {
  let firstInstant = calendar.startOfDay(start)
  let lastInstantExclusive = calendar.startOfDay(calendar.offset(end, byDays: 1))

  let samples = try await queryMulti(
    healthKitStore: healthKitStore,
    types: [
      .quantityType(forIdentifier: .bodyMass)!,
      .quantityType(forIdentifier: .bodyFatPercentage)!,
      .quantityType(forIdentifier: .bodyMassIndex)!,
      .quantityType(forIdentifier: .leanBodyMass)!,
      .quantityType(forIdentifier: .waistCircumference)!,
    ],
    startDate: firstInstant,
    endDate: lastInstantExclusive
  )

  var sampleObservedTimezones = [GregorianCalendar.FloatingDate: String]()

  for sample in samples.values.flatMap({ $0 }) {
    if
      let zoneId = sample.metadata?[HKMetadataKeyTimeZone] as? String,
      let zone = TimeZone(identifier: zoneId)
    {
      let date = GregorianCalendar(timeZone: zone).floatingDate(of: sample.startDate)
      sampleObservedTimezones[date] = zoneId
    }
  }

  // Fill in the blanks
  let resolver = UserHistoryStore.shared.resolver()
  for date in calendar.enumerate(start ... end) where !sampleObservedTimezones.keys.contains(date) {
    sampleObservedTimezones[date] = resolver.timeZone(for: date).identifier
  }

  return BodyPatch(
    bodyMass: (samples[.quantityType(forIdentifier: .bodyMass)!] ?? [])
      .map { sample in LocalQuantitySample(sample as! HKQuantitySample, unit: QuantityUnit(.bodyMass)) },
    bodyFatPercentage: (samples[.quantityType(forIdentifier: .bodyFatPercentage)!] ?? [])
      .map { sample in LocalQuantitySample(sample as! HKQuantitySample, unit: QuantityUnit(.bodyFatPercentage)) },
    bodyMassIndex: (samples[.quantityType(forIdentifier: .bodyMassIndex)!] ?? [])
      .map { sample in LocalQuantitySample(sample as! HKQuantitySample, unit: QuantityUnit(.bodyMassIndex)) },
    waistCircumference: (samples[.quantityType(forIdentifier: .waistCircumference)!] ?? [])
      .map { sample in LocalQuantitySample(sample as! HKQuantitySample, unit: QuantityUnit(.waistCircumference)) },
    leanBodyMass: (samples[.quantityType(forIdentifier: .leanBodyMass)!] ?? [])
      .map { sample in LocalQuantitySample(sample as! HKQuantitySample, unit: QuantityUnit(.leanBodyMass)) },
    timeZones: sampleObservedTimezones
  )
}
