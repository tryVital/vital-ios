import Foundation

public struct QuantitySample: Equatable, Hashable, Encodable {
  public let id: UUID?
  public var value: Double
  public var startDate: Date
  public var endDate: Date
  public var sourceBundle: String?
  public var type: String?
  public var unit: String
  
  public init(
    id: UUID? = nil,
    value: Double,
    startDate: Date,
    endDate: Date,
    sourceBundle: String? = nil,
    type: String? = nil,
    unit: String
  ) {
    self.id = id
    self.value = value
    self.startDate = startDate
    self.endDate = endDate
    self.sourceBundle = sourceBundle
    self.type = type
    self.unit = unit
  }
  
  public init(
    id: UUID? = nil,
    value: Double,
    date: Date,
    sourceBundle: String? = nil,
    type: String? = nil,
    unit: String
  ) {
    self.init(
      id: id,
      value: value,
      startDate: date,
      endDate: date,
      sourceBundle: sourceBundle,
      type: type,
      unit: unit
    )
  }
}
