import Foundation

public struct ScalarSample: Equatable, Decodable {
  public let timestamp: Date

  public let value: Float
  public let type: String?
  public let unit: String

  public init(timestamp: Date, value: Float, type: String?, unit: String) {
    self.timestamp = timestamp
    self.value = value
    self.type = type
    self.unit = unit
  }
}

public struct IntervalSample: Equatable, Decodable, Hashable {
  public let start: Date
  public let end: Date

  public let value: Float
  public let type: String?
  public let unit: String

  public init(start: Date, end: Date, value: Float, type: String?, unit: String) {
    self.start = start
    self.end = end
    self.value = value
    self.type = type
    self.unit = unit
  }
}

public struct GroupedSamplesResponse<Sample: Equatable & Decodable>: Equatable, Decodable {
  public let groups: [GroupedSamples<Sample>]
  public let next: String?

  public init(groups: [GroupedSamples<Sample>], next: String?) {
    self.groups = groups
    self.next = next
  }
}

public struct GroupedSamples<Sample: Equatable & Decodable>: Equatable, Decodable {
  public let source: Source
  public let data: [Sample]

  public init(source: Source, data: [Sample]) {
    self.source = source
    self.data = data
  }
}
