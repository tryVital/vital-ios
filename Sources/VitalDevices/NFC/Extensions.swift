/**
 MIT License
 
 Copyright (c) 2022 Guido Soranzio
 
 Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
 
 The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */

import Foundation
import CryptoKit

extension Data {
  var sha1: String { Insecure.SHA1.hash(data: self).makeIterator().reduce("", { $0 + String(format: "%02x", $1)}) }
  
  func hexDump(header: String = "", address: Int = -1, startBlock: Int = -1, escaping: Bool = false) -> String {
    var offset = startIndex
    var offsetEnd = offset
    var str = (header.isEmpty || escaping) ? "" : "\(header)\n"
    while offset < endIndex {
      _ = formIndex(&offsetEnd, offsetBy: 8, limitedBy: endIndex)
      if address != -1 { str += (address + offset).hex + " "}
      if startBlock != -1 { str += "#\((startBlock + offset / 8).hex) " }
      if address != -1 || startBlock != -1 { str += " " }
      str += "\(self[offset ..< offsetEnd].reduce("", { $0 + $1.hex + " "}))"
      str += String(repeating: "   ", count: 8 - distance(from: offset, to: offsetEnd))
      str += "\(self[offset ..< offsetEnd].reduce(" ", { $0 + ((isprint(Int32($1)) != 0) ? String(Unicode.Scalar($1)) : "." ) }))\n"
      _ = formIndex(&offset, offsetBy: 8, limitedBy: endIndex)
    }
    str.removeLast()
    if escaping {
      return str.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"").replacingOccurrences(of: "\n", with: "\\n")
    }
    return str
  }
}

extension UInt8 {
  var hex: String { String(format: "%.2X", self) }
}

extension UInt16 {
  init(_ data: Data) {
    self = UInt16(data[data.startIndex]) + UInt16(data[data.startIndex + 1]) << 8
  }
  
  var data: Data { Data([UInt8(self & 0xFF), UInt8(self >> 8)]) }
}

extension Int {
  var hex: String { String(format: "%.2x", self) }
}
