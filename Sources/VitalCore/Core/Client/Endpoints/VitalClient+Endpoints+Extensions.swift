import Foundation

func makeBaseQuery(
  startDate: Date,
  endDate: Date?,
  provider: Provider.Slug? = nil
) -> [(String, String?)] {
  
  let formatter = DateFormatter()
  formatter.dateFormat = "yyyy/MM/dd"
  let startDateString = formatter.string(from: startDate)
  
  var query: [(String, String?)] = [("start_date", startDateString)]
  
  if let endDate = endDate {
    let endDateString = formatter.string(from: endDate)
    query.append(("end_date", endDateString))
  }
  
  if let provider = provider {
    query.append(("provider", provider.rawValue))
  }
  
  return query
}
