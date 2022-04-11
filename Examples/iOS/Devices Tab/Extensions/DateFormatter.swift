import Foundation

extension Date {
  func getDay(format: String = "HH:mm:ss") -> String {
    let dateformat = DateFormatter()
    dateformat.dateFormat = format
    return dateformat.string(from: self)
  }
  
  func getDate(format: String = "E MMM yy") -> String {
    let dateformat = DateFormatter()
    dateformat.dateFormat = format
    return dateformat.string(from: self)
  }
}
