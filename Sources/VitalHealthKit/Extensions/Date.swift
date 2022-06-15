import Foundation
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
    var calendar = Calendar.current
    calendar.timeZone = TimeZone(abbreviation: "UTC")!
    
    let date = calendar.date(bySettingHour: 0, minute: 0, second: 0, of: self)!
    return date
  }
  
  var dayEnd: Date {
    let components = DateComponents(day: 1)
    return Calendar.current.date(byAdding: components, to: dayStart) ?? self
  }
}
