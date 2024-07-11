import Foundation

public struct ScalarSample: Equatable, Decodable {
  public let timestamp: Date

  public let value: Float
  public let type: String?
  public let unit: String
  public let timezoneOffset: Int?

  public init(timestamp: Date, value: Float, type: String?, unit: String, timezoneOffset: Int?) {
    self.timestamp = timestamp
    self.value = value
    self.type = type
    self.unit = unit
    self.timezoneOffset = timezoneOffset
  }
}

public struct IntervalSample: Equatable, Decodable, Hashable {
  public let start: Date
  public let end: Date

  public let value: Float
  public let type: String?
  public let unit: String
  public let timezoneOffset: Int?

  public init(start: Date, end: Date, value: Float, type: String?, unit: String, timezoneOffset: Int?) {
    self.start = start
    self.end = end
    self.value = value
    self.type = type
    self.unit = unit
    self.timezoneOffset = timezoneOffset
  }
}

public struct BloodPressureSample: Equatable, Decodable, Hashable {
  public let timestamp: Date

  public let systolic: Float
  public let diastolic: Float

  public let type: String?
  public let unit: String
  public let timezoneOffset: Int?

  public init(timestamp: Date, systolic: Float, diastolic: Float, type: String?, unit: String, timezoneOffset: Int?) {
    self.timestamp = timestamp
    self.systolic = systolic
    self.diastolic = diastolic
    self.type = type
    self.unit = unit
    self.timezoneOffset = timezoneOffset
  }
}


public struct GroupedSamplesResponse<Sample: Equatable & Decodable>: Equatable, Decodable {
  public let groups: [Provider.Slug: [GroupedSamples<Sample>]]
  public let nextCursor: String?

  public init(groups: [Provider.Slug: [GroupedSamples<Sample>]], nextCursor: String?) {
    self.groups = groups
    self.nextCursor = nextCursor
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let groups = try container.decode([String: [GroupedSamples<Sample>]].self, forKey: .groups)
    self.nextCursor = try container.decodeIfPresent(String.self, forKey: .nextCursor)
    self.groups = Dictionary(
      uniqueKeysWithValues: groups.map { key, value in (Provider.Slug(rawValue: key)!, value) }
    )
  }

  public enum CodingKeys: String, Swift.CodingKey {
    case groups
    case nextCursor = "next_cursor"
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
