import Foundation

public struct BulkQuantitySample: Hashable, Encodable {
  public let anchor: Date

  public var value: [Double]
  public var startOffset: [Double]
  public var endOffset: [Double]

  public let sourceBundle: String?
  public let productType: String?
  public let type: String?
  public let metadata: [String: String]?

  public init(anchor: Date, value: [Double], startOffset: [Double], endOffset: [Double], sourceBundle: String?, productType: String?, type: String?, metadata: [String: String]? = nil) {
    self.anchor = anchor
    self.value = value
    self.startOffset = startOffset
    self.endOffset = endOffset
    self.sourceBundle = sourceBundle
    self.productType = productType
    self.type = type
    self.metadata = metadata
  }
}
