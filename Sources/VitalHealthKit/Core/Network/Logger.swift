//import os
//
//public struct Logger {
//  let enable: Bool
//  let logger: os.Logger?
//  
//  init(enabled: Bool, domain: String) {
//    if enabled {
//      self.logger = os.Logger(subsystem: domain, category: "")
//    }
//  }
//  
//  func log(level: OSLogType, message: OSLogMessage) {
//    self.logger?.log(level: level, message)
//  }
//}
