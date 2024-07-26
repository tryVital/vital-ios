import Foundation

public struct LocalQuantitySample: Hashable, Encodable {
  
  public var value: Double
  public var startDate: Date
  public var endDate: Date
  public var sourceBundle: String?
  public var productType: String?
  public var type: SourceType?
  public var unit: Unit

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
    unit: Unit
  ) {
    self.value = value
    self.startDate = startDate
    self.endDate = endDate
    self.sourceBundle = sourceBundle
    self.productType = productType
    self.type = type
    self.unit = unit
  }
  
  public init(
    value: Double,
    date: Date,
    sourceBundle: String? = nil,
    productType: String? = nil,
    type: SourceType? = nil,
    timezoneOffset: Int? = nil,
    unit: Unit
  ) {
    self.init(
      value: value,
      startDate: date,
      endDate: date,
      sourceBundle: sourceBundle,
      productType: productType,
      type: type,
      unit: unit
    )
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

    public var description: String {
      rawValue
    }
  }
}
