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

extension NFC {
  func execute(_ taskRequest: TaskRequest) async throws {
    switch taskRequest {
      case .dump:
        
        try await readRaw(0x1A00, 64)
        try await readRaw(0x1C00, 512)
        if sensor.type == .libre1 {
          try await readRaw(0xFFAC, 36)
          try await readRaw(0xF860, 244 * 8)
        }
        
        let (_, readData) = try await read(fromBlock: 0, count: 43 + 201)
        sensor.fram = Data(readData)
        
      case .reset:
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
            
            try await writeRaw(commandsFramAddress + a1Offset, e0Address.data)
            try await writeRaw(commandsFramAddress, patchedCRC.data)
            try await send(sensor.getPatchInfoCommand)
            try await writeRaw(commandsFramAddress + a1Offset, a1Address.data)
            try await writeRaw(commandsFramAddress, originalCRC.data)
            
            let (_, data) = try await read(fromBlock: 0, count: 43)
            sensor.fram = Data(data)
            
          default:
            break
        }
        
      case .prolong:
        
        let (footerAddress, footerFram) = try await readRaw(0xF860 + 40 * 8, 3 * 8)
        
        let maxLifeOffset = 6
        
        var patchedFram = Data(footerFram)
        patchedFram[maxLifeOffset ... maxLifeOffset + 1] = Data([0xFF, 0xFF])
        let patchedCRC = crc16(patchedFram[2 ..< 3 * 8])
        patchedFram[0 ... 1] = patchedCRC.data
        
        try await writeRaw(footerAddress + maxLifeOffset, patchedFram[maxLifeOffset ... maxLifeOffset + 1])
        try await writeRaw(footerAddress, patchedCRC.data)
        
        let (_, data) = try await read(fromBlock: 0, count: 43)
        sensor.fram = Data(data)
        
      case .unlock:
        if sensor.securityGeneration < 1 {
          throw NFCError.commandNotSupported
        }
        
        _ = try await send(sensor.unlockCommand)
        
        let (_, data) = try await read(fromBlock: 0, count: 43)
        sensor.fram = Data(data)
        
      case .activate:
        _ = try await send(sensor.activationCommand)
        
        let (_, data) = try await read(fromBlock: 0, count: 43)
        sensor.fram = Data(data)
        
      default:
        break
    }
  }
  
  @discardableResult
  func send(_ cmd: NFCCommand) async throws -> Data {
    let output = try await connectedTag?.customCommand(requestFlags: .highDataRate, customCommandCode: cmd.code, customRequestParameters: cmd.parameters)
    return Data(output!)
  }
  
  func read(fromBlock start: Int, count blocks: Int, requesting: Int = 3, retries: Int = 5) async throws -> (Int, Data) {
    
    var buffer = Data()
    
    var remaining = blocks
    var requested = requesting
    var retry = 0
    
    while remaining > 0 && retry <= retries {
      
      let blockToRead = start + buffer.count / 8
      
      do {
        let dataArray = try await connectedTag?.readMultipleBlocks(requestFlags: .highDataRate, blockRange: NSRange(blockToRead ... blockToRead + requested - 1))
        
        for data in dataArray! {
          buffer += data
        }
        
        remaining -= requested
        
        if remaining != 0 && remaining < requested {
          requested = remaining
        }
        
      } catch {
        
        retry += 1
        if retry <= retries {
          AudioServicesPlaySystemSound(1520)    // "pop" vibration
          try await Task.sleep(nanoseconds: 250_000_000)
          
        } else {
          if sensor.securityGeneration < 2 || taskRequest == .none {
            session?.invalidate(errorMessage: errorMessage)
          }
          throw NFCError.read
        }
      }
    }
    
    return (start, buffer)
  }
  
  @discardableResult func readRaw(_ address: Int, _ bytes: Int) async throws -> (Int, Data) {
    
    var buffer = Data()
    var remainingBytes = bytes
    
    while remainingBytes > 0 {
      
      let addressToRead = address + buffer.count
      let bytesToRead = min(remainingBytes, 24)
      
      var remainingWords = remainingBytes / 2
      if remainingBytes % 2 == 1 || ( remainingBytes % 2 == 0 && addressToRead % 2 == 1 ) { remainingWords += 1 }
      let wordsToRead = min(remainingWords, 12)   // real limit is 15
      
      let readRawCommand = NFCCommand(code: 0xA3, parameters: sensor.backdoor + [UInt8(addressToRead & 0xFF), UInt8(addressToRead >> 8), UInt8(wordsToRead)])
      
      do {
        let output = try await connectedTag?.customCommand(requestFlags: .highDataRate, customCommandCode: readRawCommand.code, customRequestParameters: readRawCommand.parameters)
        var data = Data(output!)
        
        if addressToRead % 2 == 1 { data = data.subdata(in: 1 ..< data.count) }
        if data.count - bytesToRead == 1 { data = data.subdata(in: 0 ..< data.count - 1) }
        
        buffer += data
        remainingBytes -= data.count
        
      } catch {
        throw NFCError.customCommandError
      }
    }
    
    return (address, buffer)
  }
  
  
  func writeRaw(_ address: Int, _ data: Data) async throws {
    
    if sensor.type != .libre1 {
      throw NFCError.commandNotSupported
    }
    
    try await send(sensor.unlockCommand)
    
    let addressToRead = (address / 8) * 8
    let startOffset = address % 8
    let endAddressToRead = ((address + data.count - 1) / 8) * 8 + 7
    let blocksToRead = (endAddressToRead - addressToRead) / 8 + 1
    
    let (readAddress, readData) = try await readRaw(addressToRead, blocksToRead * 8)
    var msg = readData.hexDump(header: "NFC: blocks to overwrite:", address: readAddress)
    var bytesToWrite = readData
    bytesToWrite.replaceSubrange(startOffset ..< startOffset + data.count, with: data)
    msg += "\(bytesToWrite.hexDump(header: "\nwith blocks:", address: addressToRead))"
    
    let startBlock = addressToRead / 8
    let blocks = bytesToWrite.count / 8
    
    if address >= 0xF860 {    // write to FRAM blocks
      
      let requestBlocks = 2    // 3 doesn't work
      
      let requests = Int(ceil(Double(blocks) / Double(requestBlocks)))
      let remainder = blocks % requestBlocks
      var blocksToWrite = [Data](repeating: Data(), count: blocks)
      
      for i in 0 ..< blocks {
        blocksToWrite[i] = Data(bytesToWrite[i * 8 ... i * 8 + 7])
      }
      
      for i in 0 ..< requests {
        
        let startIndex = startBlock - 0xF860 / 8 + i * requestBlocks
        // TODO: simplify by using min()
        let endIndex = startIndex + (i == requests - 1 ? (remainder == 0 ? requestBlocks : remainder) : requestBlocks) - (requestBlocks > 1 ? 1 : 0)
        let blockRange = NSRange(startIndex ... endIndex)
        
        var dataBlocks = [Data]()
        for j in startIndex ... endIndex { dataBlocks.append(blocksToWrite[j - startIndex]) }
        
        do {
          try await connectedTag?.writeMultipleBlocks(requestFlags: .highDataRate, blockRange: blockRange, dataBlocks: dataBlocks)
        } catch {
          throw NFCError.write
        }
      }
    }
    
    try await send(sensor.lockCommand)
  }
  
  func write(fromBlock startBlock: Int, _ data: Data) async throws {
    var startIndex = startBlock
    let endBlock = startBlock + data.count / 8 - 1
    let requestBlocks = 2    // 3 doesn't work
    
    while startIndex <= endBlock {
      let endIndex = min(startIndex + requestBlocks - 1, endBlock)
      var dataBlocks = [Data]()
      for i in startIndex ... endIndex {
        dataBlocks.append(Data(data[(i - startBlock) * 8 ... (i - startBlock) * 8 + 7]))
      }
      let blockRange = NSRange(startIndex ... endIndex)
      do {
        try await connectedTag?.writeMultipleBlocks(requestFlags: .highDataRate, blockRange: blockRange, dataBlocks: dataBlocks)
      } catch {
        throw NFCError.write
      }
      startIndex = endIndex + 1
    }
  }
}
