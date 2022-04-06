import Foundation

public struct QuantitySample: Encodable {
  public let id: UUID?
  public let value: Double
  public let startDate: Date
  public let endDate: Date
  public let sourceBundle: String
  
  public init(
    id: UUID? = nil,
    value: Double,
    startDate: Date,
    endDate: Date,
    sourceBundle: String = ""
  ) {
    self.id = id
    self.value = value
    self.startDate = startDate
    self.endDate = endDate
    self.sourceBundle = sourceBundle
  }
}
