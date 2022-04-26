extension String {
  func append(_ path: String) -> String {    
    return "\(self)/\(path)"
  }
}
