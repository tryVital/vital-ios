/**
 MIT License
 
 Copyright (c) 2022 Guido Soranzio
 
 Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
 
 The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */

import Foundation
import AVFoundation
import CoreNFC

struct NFCCommand {
  let code: Int
  var parameters: Data = Data()
  var description: String = ""
}

enum NFCError: LocalizedError {
  case commandNotSupported
  case customCommandError
  case read
  case readBlocks
  case write
  
  var errorDescription: String? {
    switch self {
      case .commandNotSupported: return "command not supported"
      case .customCommandError:  return "custom command error"
      case .read:                return "read error"
      case .readBlocks:          return "reading blocks error"
      case .write:               return "write error"
    }
  }
}

extension Sensor {
  
  var backdoor: Data {
    switch self.type {
      case .libre1:    return Data([0xc2, 0xad, 0x75, 0x21])
      case .libreProH: return Data([0xc2, 0xad, 0x00, 0x90])
      default:         return Data([0xde, 0xad, 0xbe, 0xef])
    }
  }
  
  var activationCommand: NFCCommand {
    switch self.type {
      case .libre1:
        return NFCCommand(code: 0xA0, parameters: backdoor, description: "activate")
      case .libreProH:
        return NFCCommand(code: 0xA0, parameters: backdoor + readerSerial, description: "activate")
      case .libre2:
        return nfcCommand(.activate)
      default:
        return NFCCommand(code: 0x00)
    }
  }
  
  var getPatchInfoCommand: NFCCommand { NFCCommand(code: 0xA1, description: "get patch info") }
  
  // Libre 1
  var lockCommand: NFCCommand         { NFCCommand(code: 0xA2, parameters: backdoor, description: "lock") }
  var readRawCommand: NFCCommand      { NFCCommand(code: 0xA3, parameters: backdoor, description: "read raw") }
  var unlockCommand: NFCCommand       { NFCCommand(code: 0xA4, parameters: backdoor, description: "unlock") }
  
  enum Subcommand: UInt8, CustomStringConvertible {
    case unlock          = 0x1a    // lets read FRAM in clear and dump further blocks with B0/B3
    case activate        = 0x1b
    case enableStreaming = 0x1e
    case getSessionInfo  = 0x1f    // GEN_SECURITY_CMD_GET_SESSION_INFO
    case unknown0x10     = 0x10    // returns the number of parameters + 3
    case unknown0x1c     = 0x1c
    case unknown0x1d     = 0x1d    // disables Bluetooth
                                   // Gen2
    case readChallenge   = 0x20    // returns 25 bytes
    case readBlocks      = 0x21
    case readAttribute   = 0x22    // returns 6 bytes ([0]: sensor state)
    
    var description: String {
      switch self {
        case .unlock:          return "unlock"
        case .activate:        return "activate"
        case .enableStreaming: return "enable BLE streaming"
        case .getSessionInfo:  return "get session info"
        case .readChallenge:   return "read security challenge"
        case .readBlocks:      return "read FRAM blocks"
        case .readAttribute:   return "read patch attribute"
        default:               return "[unknown: 0x\(rawValue.hex)]"
      }
    }
  }
  
  
  func nfcCommand(_ code: Subcommand, parameters: Data = Data(), secret: UInt16 = 0) -> NFCCommand {
    return NFCCommand(code: 0xA1, parameters: Data([code.rawValue]) + parameters, description: code.description)
  }
}

enum TaskRequest {
  case enableStreaming
  case readFRAM
  case unlock
  case dump
  case reset
  case prolong
  case activate
}

public class NFC: NSObject, NFCTagReaderSessionDelegate {
  
  var session: NFCTagReaderSession?
  var connectedTag: NFCISO15693Tag?
  var systemInfo: NFCISO15693SystemInfo!
  var sensor: Sensor!
  
  let readingMessage: String
  let errorMessage: String
  let completionMessage: String
  private var continuation: CheckedContinuation<[Glucose], Error>?
  private let queue: DispatchQueue
  
  var taskRequest: TaskRequest? {
    didSet {
      guard taskRequest != nil else { return }
      startSession()
    }
  }
  
  var isAvailable: Bool {
    return NFCTagReaderSession.readingAvailable
  }
  
  public init(
    readingMessage: String,
    errorMessage: String,
    completionMessage: String,
    continuation: CheckedContinuation<[Glucose], Error>?,
    queue: DispatchQueue
  ) {
    self.readingMessage = readingMessage
    self.errorMessage = errorMessage
    self.completionMessage = completionMessage
    self.continuation = continuation
    self.queue = queue
    super.init()
  }
  
  deinit {
    print("NFC deinit")
  }
  
  public func startSession() {
    session = NFCTagReaderSession(pollingOption: [.iso15693], delegate: self, queue: queue)
    session?.alertMessage = readingMessage
    session?.begin()
  }
  
  public func tagReaderSessionDidBecomeActive(_ session: NFCTagReaderSession) {}
  
  public func tagReaderSession(_ session: NFCTagReaderSession, didInvalidateWithError error: Error) {
    guard continuation != nil else { return }

    if let readerError = error as? NFCReaderError {
      if readerError.code != .readerSessionInvalidationErrorUserCanceled {
        continuation?.resume(throwing: DeviceReadingError.failedReading)
        continuation = nil
        
        session.invalidate(errorMessage: "Connection failure: \(readerError.localizedDescription)")
      }
    }
  }
  
  public func tagReaderSession(_ session: NFCTagReaderSession, didDetect tags: [NFCTag]) {
    guard let firstTag = tags.first else { return }
    guard case .iso15693(let tag) = firstTag else { return }
//    guard continuation != nil else { return }
    
    Task {
      do {
        try await session.connect(to: firstTag)
        connectedTag = tag
      } catch {
        continuation?.resume(throwing: DeviceReadingError.failedReading)
        continuation = nil
        
        session.invalidate(errorMessage: errorMessage)
        return
      }
      
      var patchInfo: PatchInfo = Data()
      let retries = 5
      var requestedRetry = 0
      var failedToScan = false
      
      repeat {
        
        failedToScan = false
        if requestedRetry > 0 {
          AudioServicesPlaySystemSound(1520)
        }
        
        do {
          patchInfo = try await tag.customCommand(requestFlags: .highDataRate, customCommandCode: 0xA1, customRequestParameters: Data())
        } catch {
          failedToScan = true
        }
        
        do {
          systemInfo = try await tag.systemInfo(requestFlags: .highDataRate)
          AudioServicesPlaySystemSound(1520)
        } catch {
          if requestedRetry > retries {
            continuation?.resume(throwing: DeviceReadingError.failedReading)
            continuation = nil
            
            session.invalidate(errorMessage: errorMessage)
            return
          }
          failedToScan = true
          requestedRetry += 1
        }
        
        do {
          patchInfo = try await tag.customCommand(requestFlags: .highDataRate, customCommandCode: 0xA1, customRequestParameters: Data())
        } catch {
          if requestedRetry > retries && systemInfo != nil {
            requestedRetry = 0
          } else {
            if !failedToScan {
              failedToScan = true
              requestedRetry += 1
            }
          }
        }
        
      } while failedToScan && requestedRetry > 0
      
      guard patchInfo.count != 0 else {
        continuation?.resume(throwing: DeviceReadingError.failedReading)
        continuation = nil
        
        session.invalidate(errorMessage: errorMessage)
        return
      }
      
      let sensorType = SensorType(patchInfo: patchInfo)
      switch sensorType {
        case .libre3, .libre2, .libreProH:
          continuation?.resume(throwing: DeviceReadingError.wrongDevice)
          continuation = nil
          
          session.invalidate(errorMessage: errorMessage)
          return

        default:
          sensor = Sensor()
      }
      sensor.patchInfo = patchInfo
      
      sensor.uid = Data(tag.identifier.reversed())
      
      if taskRequest == .unlock ||
          taskRequest == .dump ||
          taskRequest == .reset ||
          taskRequest == .prolong ||
          taskRequest == .activate {
        
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
        taskRequest = .none
        
        continuation?.resume(throwing: DeviceReadingError.failedReading)
        continuation = nil

        session.invalidate(errorMessage: errorMessage)
        return
      }
      
      var blocks = 22 + 24    // (32 * 6 / 8)
      if taskRequest == .readFRAM {
        blocks = 244
      }
      
      do {
        let (_, data) = try await read(fromBlock: 0, count: blocks)
        let lastReadingDate = Date()
        
        sensor.lastReadingDate = lastReadingDate
        
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
        session.invalidate()
        
        sensor.fram = Data(data)
        
      } catch {
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
        
        continuation?.resume(throwing: DeviceReadingError.failedReading)
        continuation = nil
        
        session.invalidate(errorMessage: errorMessage)
        return
      }
      
      session.alertMessage = completionMessage
      
      if taskRequest == .readFRAM {
        taskRequest = .none
      }
      

      let uniqueValues = (sensor.factoryTrend + sensor.factoryHistory).unique(by: \.date)
      let ordered = uniqueValues.sorted { $0.date > $1.date }
      
      continuation?.resume(returning: ordered)
    }
  }
}
