import Foundation

public struct QuantitySample: Equatable, Hashable, Encodable {
  
  public let id: String?
  public var value: Double
  public var startDate: Date
  public var endDate: Date
  public var sourceBundle: String?
  public var productType: String?
  public var type: String?
  public var unit: String
  
  private var metadata: VitalAnyEncodable?
  
  public init(
    id: String? = nil,
    value: Double,
    startDate: Date,
    endDate: Date,
    sourceBundle: String? = nil,
    productType: String? = nil,
    type: String? = nil,
    unit: String,
    metadata: VitalAnyEncodable? = nil
  ) {
    self.id = id
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
    id: String? = nil,
    value: Double,
    date: Date,
    sourceBundle: String? = nil,
    productType: String? = nil,
    type: String? = nil,
    unit: String,
    metadata: VitalAnyEncodable? = nil
  ) {
    self.init(
      id: id,
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

  public static func == (lhs: QuantitySample, rhs: QuantitySample) -> Bool {
    lhs.id == rhs.id &&
    lhs.value == rhs.value &&
    lhs.startDate == rhs.startDate &&
    lhs.endDate == rhs.endDate &&
    lhs.sourceBundle == rhs.sourceBundle &&
    lhs.productType == rhs.productType &&
    lhs.type == rhs.type &&
    lhs.unit == rhs.unit
  }
  
  public func hash(into hasher: inout Hasher) {
    hasher.combine(id)
    hasher.combine(value)
    hasher.combine(startDate)
    hasher.combine(endDate)
    hasher.combine(sourceBundle)
    hasher.combine(productType)
    hasher.combine(type)
    hasher.combine(unit)
  }
}
