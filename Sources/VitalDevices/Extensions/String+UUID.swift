
extension String {
  var fullUUID: String {
    let suffix =  "-0000-1000-8000-00805f9b34fb"
    if self.count == 4 {
      return "0000" + self.lowercased() + suffix
    }
    
    if self.count == 8 {
      return self.lowercased() + suffix
    }
    
    return self
  }
}
