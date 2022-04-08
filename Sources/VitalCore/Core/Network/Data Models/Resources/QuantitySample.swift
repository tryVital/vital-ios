import Foundation

public struct QuantitySample: Equatable, Hashable, Encodable {
  public let id: UUID?
  public let value: Double
  public let startDate: Date
  public let endDate: Date
  public let sourceBundle: String?
  public let type: String?
  public let unit: String
  
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
}
