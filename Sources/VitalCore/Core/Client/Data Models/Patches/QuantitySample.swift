import Foundation

public struct LocalQuantitySample: Hashable, Encodable {
  
  public var value: Double
  public var startDate: Date
  public var endDate: Date
  public var sourceBundle: String?
  public var productType: String?
  public var type: SourceType?
  public var unit: Unit
  public var metadata: [String: String]?

  public var sourceType: SourceType {
    switch type {
    case .unknown?, nil:
      return .infer(sourceBundle: sourceBundle, productType: productType)

    case let type?:
      return type
    }
  }

  public init(
    value: Double,
    startDate: Date,
    endDate: Date,
    sourceBundle: String? = nil,
    productType: String? = nil,
    type: SourceType? = nil,
    timezoneOffset: Int? = nil,
    unit: Unit,
    metadata: [String: String]? = nil
  ) {
    self.value = value
    self.startDate = startDate
    self.endDate = endDate
    self.sourceBundle = sourceBundle
    self.productType = productType
    self.type = type
    self.unit = unit
    self.metadata = metadata
  }
  
  public init(
    value: Double,
    date: Date,
    sourceBundle: String? = nil,
    productType: String? = nil,
    type: SourceType? = nil,
    timezoneOffset: Int? = nil,
    unit: Unit,
    metadata: [String: String]? = nil
  ) {
    self.init(
      value: value,
      startDate: date,
      endDate: date,
      sourceBundle: sourceBundle,
      productType: productType,
      type: type,
      unit: unit,
      metadata: metadata
    )
  }

  public static func == (lhs: LocalQuantitySample, rhs: LocalQuantitySample) -> Bool {
    lhs.value == rhs.value &&
    lhs.startDate == rhs.startDate &&
    lhs.endDate == rhs.endDate &&
    lhs.sourceBundle == rhs.sourceBundle &&
    lhs.productType == rhs.productType &&
    lhs.type == rhs.type &&
    lhs.unit == rhs.unit &&
    lhs.metadata == lhs.metadata
  }

  public func hash(into hasher: inout Hasher) {
    hasher.combine(value)
    hasher.combine(startDate)
    hasher.combine(endDate)
    hasher.combine(sourceBundle)
    hasher.combine(productType)
    hasher.combine(type)
    hasher.combine(unit)
    hasher.combine(metadata)
  }

  public enum Unit: String, Encodable, CustomStringConvertible {
    case kg
    case centimeter
    case bpm
    case rmssd
    case percentage = "%"
    case kcal
    case count
    case meter
    case vo2Max = "mL/kg/min"
    case glucose = "mmol/L"
    case mmHg
    case mL
    case gram
    case minute
    case degreeCelsius = "\u{00B0}C"
    case stage
    case mg
    case ug = "\u{03BC}g"

    public var description: String {
      rawValue
    }
  }
}
