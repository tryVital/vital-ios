import Foundation

func makeBaseDatesQuery(
  startDate: Date,
  endDate: Date?
) -> [(String, String?)] {
  
  let formatter = DateFormatter()
  formatter.dateFormat = "yyyy/MM/dd"
  let startDateString = formatter.string(from: startDate)
  
  var query: [(String, String?)] = [("start_date", startDateString)]
  
  if let endDate = endDate {
    let endDateString = formatter.string(from: endDate)
    query.append(("end_date", endDateString))
  }
  
  return query
}
