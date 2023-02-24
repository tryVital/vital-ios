import Foundation

enum RACPResponse {
  case success
  case noRecordsFound
  case notCompleted
  case unknown(code: UInt8)

  case invalidPayloadStructure

  var code: Int {
    switch self {
    case .success:
      return 1
    case .noRecordsFound:
      return 6
    case .notCompleted:
      return 8
    case let .unknown(code):
      return Int(code)
    case .invalidPayloadStructure:
      return -1
    }
  }

  init(data: Data) {
    // byte 0: opcode      must be 6 (RACP Response opcode)
    // byte 1: operator    must be 0 (null)
    // byte 2: requestcode must be 1 (Store All Records opcode)
    guard data.count >= 4, data[0] == 6, data[1] == 0, data[2] == 1 else {
      self = .invalidPayloadStructure
      return
    }

    // byte 3: responsecode
    let responseCode = data[3]

    switch responseCode {
    case 1:
      self = .success
    case 6:
      self = .noRecordsFound
    case 8:
      self = .notCompleted
    default:
      self = .unknown(code: responseCode)
    }
  }
}
