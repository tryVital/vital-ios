import Foundation

func summarizeError(_ error: any Error) -> String {
  if type(of: error) is NSError.Type {
    let error = error as NSError
    return "\(error.domain) \(error.code) \(error.localizedDescription)"
  }

  return String(reflecting: error)
}
