import Foundation

/// UTC Gregorian calendar for standard statistical queries.
let vitalCalendar: Calendar = {
  var calendar = Calendar(identifier: .gregorian)
  calendar.timeZone = TimeZone(abbreviation: "UTC")!
  return calendar
}()

extension Date {
  
  static func dateAgo(_ date: Date = .init(), days: Int) -> Date {
    let daysAgoDate = vitalCalendar.date(byAdding: .day, value: -abs(days), to: date)
    let beginningOfTheDay = daysAgoDate!.dayStart
    
    return beginningOfTheDay
  }
  
  var dateComponentsForActivityQuery: DateComponents {
    let units: Set<Calendar.Component> = [.day, .month, .year, .era]
    var dateComponents = vitalCalendar.dateComponents(units, from: self)
    dateComponents.calendar = vitalCalendar
    
    return dateComponents
  }
  
  var dayStart: Date {
    return vitalCalendar.startOfDay(for: self)
  }
  
  /// End of the day (exclusive)
  /// Equivalent to the first instant of the next day.
  var dayEnd: Date {
    let components = DateComponents(day: 1)
    return vitalCalendar.date(byAdding: components, to: dayStart) ?? self
  }
}

extension Date {
  func toUTC(from timeZone: TimeZone) -> Date {
    let seconds = -TimeInterval(timeZone.secondsFromGMT(for: self))
    return Date(timeInterval: seconds, since: self)
  }
}

extension Date {
  public var nextHour: Date {
    let calendar = vitalCalendar
    
    let currentMinutes = calendar.component(.minute, from: self)
    let currentSeconds = calendar.component(.second, from: self)
    
    /// Don't round, if it's already in the shape we want
    if currentMinutes == 0 && currentSeconds == 0 {
      return self
    }
    
    let minutes = calendar.component(.minute, from: self)
    let components = DateComponents(hour: 1, minute: -minutes)
    
    let reset = calendar.date(byAdding: components, to: self) ?? self
    let hour = calendar.component(.hour, from: reset)

    
    let date = vitalCalendar.date(bySettingHour: hour, minute: 0, second: 0, of: reset) ?? reset
    return date
  }
  
  public var beginningHour: Date {
    let calendar = vitalCalendar
    let currentHour = calendar.component(.hour, from: self)
    let date = vitalCalendar.date(bySettingHour: currentHour, minute: 0, second: 0, of: self)!
    return date
  }
}

extension Date {
  static func differenceInMinutes(startDate: Date, endDate: Date) -> Int? {
    let components = vitalCalendar.dateComponents([.minute], from: startDate, to: endDate)
    return components.minute
  }
}
