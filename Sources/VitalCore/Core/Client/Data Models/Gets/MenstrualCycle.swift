import Foundation

public struct MenstrualCycle: Equatable, Codable {
  public let periodStart: GregorianCalendar.Date
  @NilAsNull
  public var periodEnd: GregorianCalendar.Date?
  @NilAsNull
  public var cycleEnd: GregorianCalendar.Date?

  public let menstrualFlow: [MenstrualFlowEntry]
  public let cervicalMucus: [CervicalMucusEntry]
  public let intermenstrualBleeding: [IntermenstrualBleedingEntry]
  public let contraceptive: [ContraceptiveEntry]
  public let detectedDeviations: [DetectedDeviationEntry]
  public let ovulationTest: [OvulationTestEntry]
  public let homePregnancyTest: [HomePregnancyTestEntry]
  public let homeProgesteroneTest: [HomeProgesteroneTestEntry]
  public let sexualActivity: [SexualActivityEntry]
  public let basalBodyTemperature: [BasalBodyTemperatureEntry]

  public let source: Source

  public init(
    periodStart: GregorianCalendar.Date,
    periodEnd: GregorianCalendar.Date?,
    cycleEnd: GregorianCalendar.Date?,
    menstrualFlow: [MenstrualFlowEntry],
    cervicalMucus: [CervicalMucusEntry],
    intermenstrualBleeding: [IntermenstrualBleedingEntry],
    contraceptive: [ContraceptiveEntry],
    detectedDeviations: [DetectedDeviationEntry],
    ovulationTest: [OvulationTestEntry],
    homePregnancyTest: [HomePregnancyTestEntry],
    homeProgesteroneTest: [HomeProgesteroneTestEntry],
    sexualActivity: [SexualActivityEntry],
    basalBodyTemperature: [BasalBodyTemperatureEntry],
    source: Source
  ) {
    self.periodStart = periodStart
    self.periodEnd = periodEnd
    self.cycleEnd = cycleEnd
    self.menstrualFlow = menstrualFlow
    self.cervicalMucus = cervicalMucus
    self.intermenstrualBleeding = intermenstrualBleeding
    self.contraceptive = contraceptive
    self.detectedDeviations = detectedDeviations
    self.ovulationTest = ovulationTest
    self.homePregnancyTest = homePregnancyTest
    self.homeProgesteroneTest = homeProgesteroneTest
    self.sexualActivity = sexualActivity
    self.basalBodyTemperature = basalBodyTemperature
    self.source = source
  }
}

extension MenstrualCycle {

  public enum MenstrualFlow: String, Codable {
    case unspecified
    case none
    case light
    case medium
    case heavy
  }

  public enum MenstrualDeviation: String, Codable {
    case persistentIntermenstrualBleeding = "persistent_intermenstrual_bleeding"
    case prolongedMenstrualPeriods = "prolonged_menstrual_periods"
    case irregularMenstrualCycles = "irregular_menstrual_cycles"
    case infrequentMenstrualCycles = "infrequent_menstrual_cycles"
  }

  public enum CervicalMucusQuality: String, Codable {
    case dry
    case sticky
    case creamy
    case watery
    case eggWhite = "egg_white"
  }

  public enum ContraceptiveType: String, Codable {
    case unspecified
    case implant
    case injection
    case iud
    case intravaginalRing = "intravaginal_ring"
    case oral
    case patch
  }

  public enum OvulationTestResult: String, Codable {
    case negative
    case positive
    case luteinizingHormoneSurge = "luteinizing_hormone_surge"
    case estrogenSurge = "estrogen_surge"
    case indeterminate
  }

  public enum HomeTestResult: String, Codable {
    case negative
    case positive
    case indeterminate
  }


  public struct MenstrualFlowEntry: Equatable, Codable {
    public let date: GregorianCalendar.Date
    public let flow: MenstrualFlow

    public init(
      date: GregorianCalendar.Date,
      flow: MenstrualFlow
    ) {
      self.date = date
      self.flow = flow
    }
  }


  public struct CervicalMucusEntry: Equatable, Codable {
    public let date: GregorianCalendar.Date
    public let quality: CervicalMucusQuality

    public init(
      date: GregorianCalendar.Date,
      quality: CervicalMucusQuality
    ) {
      self.date = date
      self.quality = quality
    }
  }


  public struct IntermenstrualBleedingEntry: Equatable, Codable {
    public let date: GregorianCalendar.Date

    public init(
      date: GregorianCalendar.Date
    ) {
      self.date = date
    }
  }


  public struct ContraceptiveEntry: Equatable, Codable {
    public let date: GregorianCalendar.Date
    public let type: ContraceptiveType

    public init(
      date: GregorianCalendar.Date,
      type: ContraceptiveType
    ) {
      self.date = date
      self.type = type
    }
  }


  public struct DetectedDeviationEntry: Equatable, Codable {
    public let date: GregorianCalendar.Date
    public let deviation: MenstrualDeviation

    public init(
      date: GregorianCalendar.Date,
      deviation: MenstrualDeviation
    ) {
      self.date = date
      self.deviation = deviation
    }
  }


  public struct OvulationTestEntry: Equatable, Codable {
    public let date: GregorianCalendar.Date
    public let testResult: OvulationTestResult

    public init(
      date: GregorianCalendar.Date,
      testResult: OvulationTestResult
    ) {
      self.date = date
      self.testResult = testResult
    }
  }


  public struct HomePregnancyTestEntry: Equatable, Codable {
    public let date: GregorianCalendar.Date
    public let testResult: HomeTestResult

    public init(
      date: GregorianCalendar.Date,
      testResult: HomeTestResult
    ) {
      self.date = date
      self.testResult = testResult
    }
  }


  public struct HomeProgesteroneTestEntry: Equatable, Codable {
    public let date: GregorianCalendar.Date
    public let testResult: HomeTestResult

    public init(
      date: GregorianCalendar.Date,
      testResult: HomeTestResult
    ) {
      self.date = date
      self.testResult = testResult
    }
  }


  public struct SexualActivityEntry: Equatable, Codable {
    public let date: GregorianCalendar.Date

    @NilAsNull
    public var protectionUsed: Bool?

    public init(
      date: GregorianCalendar.Date,
      protectionUsed: Bool?
    ) {
      self.date = date
      self.protectionUsed = protectionUsed
    }
  }


  public struct BasalBodyTemperatureEntry: Equatable, Codable {
    public let date: GregorianCalendar.Date
    public let value: Double

    public init(
      date: GregorianCalendar.Date,
      value: Double
    ) {
      self.date = date
      self.value = value
    }
  }
}
