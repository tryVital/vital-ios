import Foundation

public struct GregorianCalendar {
  public static let utcTimeZone = TimeZone(secondsFromGMT: 0)!
  public static let utc = GregorianCalendar(timeZone: Self.utcTimeZone)

  let base: Calendar

  public init(timeZone: TimeZone) {
    var base = Calendar(identifier: .gregorian)
    base.timeZone = timeZone
    self.base = base
  }

  /// End inclusive
  public func enumerate(_ dateRange: ClosedRange<FloatingDate>) -> [FloatingDate] {
    guard dateRange.lowerBound != dateRange.upperBound else {
      // range.lowerBound == range.upperBound
      return [dateRange.lowerBound]
    }

    let endTime = startOfDay(dateRange.upperBound)
    var startTime = startOfDay(dateRange.lowerBound)
    precondition(startTime < endTime)

    var results = [FloatingDate]()

    while startTime <= endTime {
      results.append(self.floatingDate(of: startTime))

      guard let nextStartOfDay = base.date(byAdding: .day, value: 1, to: startTime) else {
        Self.invariantViolation()
      }
      startTime = nextStartOfDay
    }

    return results
  }

  public func floatingDate(of date: Foundation.Date) -> FloatingDate {
    let components = base.dateComponents([.year, .month, .day], from: date)
    guard let year = components.year, let month = components.month, let day = components.day else {
      Self.invariantViolation()
    }
    return FloatingDate(year: year, month: month, day: day)
  }

  public func startOfDay(_ date: FloatingDate) -> Foundation.Date {
    guard let startOfDay = base.date(from: date.dateComponents()) else {
      Self.invariantViolation()
    }
    return startOfDay
  }

  /// Return an end-exclusive UTC time range that would cover the given closed range of calendar dates with respect to `self`.
  public func timeRange(of dateRange: ClosedRange<FloatingDate>) -> Range<Foundation.Date> {
    // Since we are returning an end-exclusive UTC time range, the upper bound is the first instant
    // of the day after the end date.
    let dayAfterEndDate = offset(dateRange.upperBound, byDays: 1)

    return startOfDay(dateRange.lowerBound) ..< startOfDay(dayAfterEndDate)
  }

  public func offset(_ date: FloatingDate, byDays days: Int) -> FloatingDate {
    guard let newStartOfDay = base.date(byAdding: .day, value: days, to: startOfDay(date)) else {
      Self.invariantViolation()
    }

    return floatingDate(of: newStartOfDay)
  }

  static func invariantViolation(file: StaticString = #file, line: UInt = #line) -> Never {
    fatalError("This is not expected to happen with Gregorian calendar.", file: file, line: line)
  }
}

extension GregorianCalendar {
  public typealias Date = FloatingDate

  public struct FloatingDate: Hashable, Codable, LosslessStringConvertible, Comparable {
    private static let utcFormatter: ISO8601DateFormatter = {
      let formatter = ISO8601DateFormatter()
      formatter.formatOptions = [.withFullDate, .withColonSeparatorInTime]
      formatter.timeZone = TimeZone(secondsFromGMT: 0)
      return formatter
    }()

    public let year: Int
    public let month: Int
    public let day: Int

    public var description: String {
      let startOfDay = GregorianCalendar.utc.startOfDay(self)
      return Self.utcFormatter.string(from: startOfDay)
    }

    public init?(_ description: String) {
      guard let date = Self.utcFormatter.date(from: description) else {
        return nil
      }

      self = GregorianCalendar.utc.floatingDate(of: date)
    }

    public init(year: Int, month: Int, day: Int) {
      self.year = year
      self.month = month
      self.day = day
    }

    public init(from decoder: Decoder) throws {
      let container = try decoder.singleValueContainer()
      let rawValue = try container.decode(String.self)

      guard let date = Self(rawValue) else {
        throw DecodingError.dataCorrupted(
          .init(
            codingPath: container.codingPath,
            debugDescription: "Unrecognized date format: \(rawValue)"
          )
        )
      }

      self = date
    }

    public func encode(to encoder: Encoder) throws {
      var container = encoder.singleValueContainer()
      try container.encode(description)
    }

    public func dateComponents() -> DateComponents {
      DateComponents(year: year, month: month, day: day)
    }

    public static func <(lhs: Self, rhs: Self) -> Bool {
      lhs.year < rhs.year ||
      lhs.year == rhs.year && (
        lhs.month < rhs.month || lhs.month == rhs.month && lhs.day < rhs.day
      )
    }
  }
}
