/// Taken from here:
/// https://stackoverflow.com/a/57255549/491239
import Foundation
import CryptoKit

extension Digest {
  var bytes: [UInt8] { Array(makeIterator()) }
  
  var hexStr: String {
    bytes.map { String(format: "%02X", $0) }.joined()
  }
}

extension String {
  func sha256() -> String? {
    guard let data = self.data(using: .utf8) else {
      return nil
    }
    
    return SHA256.hash(data: data).hexStr
  }
}

extension Data {
  func base64EncodedSHA256() -> String {
    Data(SHA256.hash(data: self).bytes).base64EncodedString()
  }
}
