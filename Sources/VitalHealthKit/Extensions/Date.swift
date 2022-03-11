import Foundation
extension Date {
  
  static func dateAgo(_ date: Date = .init(), days: Int) -> Date {
   let daysAgoDate = Calendar.current.date(byAdding: .day, value: -abs(days), to: date)
    
    return daysAgoDate ?? date
  }
}
