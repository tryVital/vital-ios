import Foundation

private let vitalCalendar: Calendar = {
  var calendar = Calendar(identifier: .gregorian)
  calendar.timeZone = TimeZone(abbreviation: "UTC")!
  return calendar
}()

extension Date {
  
  static func dateAgo(_ date: Date = .init(), days: Int) -> Date {
   let daysAgoDate = Calendar.current.date(byAdding: .day, value: -abs(days), to: date)
    
    return daysAgoDate ?? date
  }
  
  var dateComponentsForActivityQuery: DateComponents {
    let units: Set<Calendar.Component> = [.day, .month, .year, .era]
    var dateComponents = Calendar.current.dateComponents(units, from: self)
    dateComponents.calendar = Calendar.current

    return dateComponents
  }
  
  var dayStart: Date {
    let date = vitalCalendar.date(bySettingHour: 0, minute: 0, second: 0, of: self)!
    return date
  }
  
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

