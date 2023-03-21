import Foundation

extension Range {
  func union(_ other: Range<Bound>) -> Range<Bound> {
    Swift.min(lowerBound, other.lowerBound) ..< Swift.max(upperBound, other.upperBound)
  }
}

extension Range where Bound == Date {
  /// Align both ends of the time interval to enclose their nearest whole UTC hour.
  /// (using `vitalCalendar`)
  func aligningToWholeHours() -> Range<Date> {
    lowerBound.beginningHour ..< upperBound.nextHour
  }
}
