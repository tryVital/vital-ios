import Foundation
import AVFoundation

import CoreNFC

extension NFC {
  
  func execute(_ taskRequest: TaskRequest) async throws {
    switch taskRequest {
      case .dump:

        do {
          var (address, data) = try await readRaw(0x1A00, 64)
          (address, data) = try await readRaw(0x1C00, 512)
          if sensor.type == .libre1 {
            (address, data) = try await readRaw(0xFFAC, 36)
            (address, data) = try await readRaw(0xF860, 244 * 8)
          }
          if sensor.type == .libreProH {
            (address, data) = try await readRaw(0xFFA8, 40)
            (address, data) = try await readRaw(0xD8E0, 22 * 8)
            (address, data) = try await readRaw(0xD998, 24 * 8)
          }
        } catch {
          
        }
        
        do {
          let (start, data) = try await read(fromBlock: 0, count: 43 + (sensor.type == .libre1 || sensor.type == .libreProH ? 201 : 0))
          sensor.fram = Data(data)
        } catch {
          
        }
              
      case .reset:
        
        if sensor.type != .libre1 && sensor.type != .libreProH {
          throw NFCError.commandNotSupported
        }
        
        switch sensor.type {
          case .libre1:
            
            let (commandsFramAddress, commmandsFram) = try await readRaw(0xF860 + 43 * 8, 195 * 8)
            
            let e0Offset = 0xFFB6 - commandsFramAddress
            let a1Offset = 0xFFC6 - commandsFramAddress
            let e0Address = UInt16(commmandsFram[e0Offset ... e0Offset + 1])
            let a1Address = UInt16(commmandsFram[a1Offset ... a1Offset + 1])
            
            
            let originalCRC = crc16(commmandsFram[2 ..< 195 * 8])
            
            var patchedFram = Data(commmandsFram)
            patchedFram[a1Offset ... a1Offset + 1] = e0Address.data
            let patchedCRC = crc16(patchedFram[2 ..< 195 * 8])
            patchedFram[0 ... 1] = patchedCRC.data
                        
            do {
              try await writeRaw(commandsFramAddress + a1Offset, e0Address.data)
              try await writeRaw(commandsFramAddress, patchedCRC.data)
              try await send(sensor.getPatchInfoCommand)
              try await writeRaw(commandsFramAddress + a1Offset, a1Address.data)
              try await writeRaw(commandsFramAddress, originalCRC.data)
              
              let (start, data) = try await read(fromBlock: 0, count: 43)
              sensor.fram = Data(data)
            } catch {
                            
            }
            
            
          case .libreProH:
                        
            do {
              try await send(sensor.unlockCommand)
              
              // header
              try await write(fromBlock: 0x00, Data([0x6A, 0xBC, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00]))
              try await write(fromBlock: 0x01, Data([0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]))
              try await write(fromBlock: 0x02, Data([0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]))
              try await write(fromBlock: 0x03, Data([0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]))
              try await write(fromBlock: 0x04, Data([0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]))
              
              // footer
              try await write(fromBlock: 0x05, Data([0x99, 0xDD, 0x10, 0x00, 0x14, 0x08, 0xC0, 0x4E]))
              try await write(fromBlock: 0x06, Data([0x14, 0x03, 0x96, 0x80, 0x5A, 0x00, 0xED, 0xA6]))
              try await write(fromBlock: 0x07, Data([0x12, 0x56, 0xDA, 0xA0, 0x04, 0x0C, 0xD8, 0x66]))
              try await write(fromBlock: 0x08, Data([0x29, 0x02, 0xC8, 0x18, 0x00, 0x00, 0x00, 0x00]))
              
              // age, trend and history indexes
              try await write(fromBlock: 0x09, Data([0xBD, 0xD1, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]))
              // trend
              for b in 0x0A ... 0x15 {
                try await write(fromBlock: b, Data([0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]))
              }
              
              // duplicated in activation
              var readCommand = sensor.readBlockCommand
              readCommand.parameters = "DF 04".bytes
              var output = try await send(readCommand)

              var writeCommand = sensor.writeBlockCommand
              writeCommand.parameters = "DF 04 20 00 DF 88 00 00 00 00".bytes
              output = try await send(writeCommand)

              output = try await send(readCommand)
              
              try await send(sensor.lockCommand)
              
            } catch {
                            
            }
            
          default:
            break
        }
        
      case .prolong:
        if sensor.type != .libre1 {
          throw NFCError.commandNotSupported
        }
        
        let (footerAddress, footerFram) = try await readRaw(0xF860 + 40 * 8, 3 * 8)
        
        let maxLifeOffset = 6
        let maxLife = Int(footerFram[maxLifeOffset]) + Int(footerFram[maxLifeOffset + 1]) << 8
        
        var patchedFram = Data(footerFram)
        patchedFram[maxLifeOffset ... maxLifeOffset + 1] = Data([0xFF, 0xFF])
        let patchedCRC = crc16(patchedFram[2 ..< 3 * 8])
        patchedFram[0 ... 1] = patchedCRC.data
        
        do {
          try await writeRaw(footerAddress + maxLifeOffset, patchedFram[maxLifeOffset ... maxLifeOffset + 1])
          try await writeRaw(footerAddress, patchedCRC.data)
          
          let (_, data) = try await read(fromBlock: 0, count: 43)
          sensor.fram = Data(data)
        } catch {
                    
        }
        
        
      case .unlock:
        if sensor.securityGeneration < 1 {
          throw NFCError.commandNotSupported
        }
        
        do {
          let output = try await send(sensor.unlockCommand)
        } catch {
                    
        }
        
        let (_, data) = try await read(fromBlock: 0, count: 43)
        sensor.fram = Data(data)
        
      case .activate:
        
        if sensor.securityGeneration > 1 {
          throw NFCError.commandNotSupported
        }
        
        do {
          if sensor.type == .libreProH {
            var readCommand = sensor.readBlockCommand
            readCommand.parameters = "DF 04".bytes
            var output = try await send(readCommand)
            try await send(sensor.unlockCommand)
            var writeCommand = sensor.writeBlockCommand
            writeCommand.parameters = "DF 04 20 00 DF 88 00 00 00 00".bytes
            output = try await send(writeCommand)
            try await send(sensor.lockCommand)
            output = try await send(readCommand)
          }
          
          let output = try await send(sensor.activationCommand)
        } catch {
                    
        }
        
        let (_, data) = try await read(fromBlock: 0, count: 43)
        sensor.fram = Data(data)
        
      default:
        break
    }
  }
}
