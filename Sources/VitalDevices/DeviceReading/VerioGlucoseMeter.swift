import VitalCore
import CombineCoreBluetooth
import Combine

struct VerioError: Error {
  let message: String

  init(_ message: String) {
    self.message = message
  }
}

internal class VerioGlucoseMeter: GlucoseMeterReadable {
  static let serviceID = CBUUID(string: "af9df7a1-e595-11e3-96b4-0002a5d5c51b")
  private static let commandCharacteristicID = CBUUID(string: "af9df7a2-e595-11e3-96b4-0002a5d5c51b")
  private static let notificationCharactersiticID = CBUUID(string: "af9df7a3-e595-11e3-96b4-0002a5d5c51b")

  private let manager: CentralManager
  private let queue: DispatchQueue

  init(
    manager: CentralManager,
    queue: DispatchQueue,
    listenTimeout: TimeInterval = 30.0
  ) {
    self.manager = manager
    self.queue = DispatchQueue(label: "io.tryvital.VitalDevices.\(Self.self)", target: queue)
  }

  func read(device: ScannedDevice) -> AnyPublisher<[LocalQuantitySample], Error> {
    return _connect(device: device) { (peripheral, command, notification) -> AnyPublisher<[LocalQuantitySample], Error> in

      let incomingData = peripheral
        .listenForUpdates(on: notification)
        .compactMap { $0 }
        .print("Data")
        .multicast(subject: PassthroughSubject())

      let output = PassthroughSubject<LocalQuantitySample, Error>()

      var cancellables = Set<AnyCancellable>()

      typealias Metadata = (timeOffset: Int, highestRecordNumber: Int, numberOfRecords: Int)
      var timeOffset: Int?
      var highestRecordNumber: Int?
      var numberOfRecords: Int?

      func sendCommand(_ data: Data, to peripheral: Peripheral) -> AnyPublisher<Data, Error> {
        incomingData
          // Listen for the ACK byte and then drop it
          // The next delivery after the ACK byte is the actual command response
          .drop(while: { ($0.first ?? 0x00) & 0x81 != 0x81 })
          .dropFirst(1)
          .first()
          .onStart(
            peripheral.writeValue(packet(data), for: command, type: .withoutResponse)
              .ignoreOutput()
              .print("Send command")
          )
          .eraseToAnyPublisher()
      }

      func sendResponseAck(to peripheral: Peripheral) -> AnyPublisher<Never, Error> {
        peripheral.writeValue(packet(Data([0x81])), for: command, type: .withoutResponse)
          .ignoreOutput()
          .eraseToAnyPublisher()
      }

      func getRecord(at index: Int, from peripheral: Peripheral) -> AnyPublisher<Data, Error> {
        // Little endian
        return sendCommand(Data([0xB3, UInt8(index & 0xFF), UInt8((index >> 8) & 0xFF)]), to: peripheral)
      }

      func withCheckedMetadata<P>(_ action: @escaping (Metadata) -> P) -> AnyPublisher<Never, Error> where P: Publisher, P.Failure == Error {
        Deferred {
          guard
            let timeOffset = timeOffset,
            let highestRecordNumber = highestRecordNumber,
            let numberOfRecords = numberOfRecords
          else {
            return Result<Metadata, Error>.failure(
              VerioError("expected all 3 metadata fields having been read; found some missing")
            ).publisher
          }

          guard numberOfRecords > 0 else {
            return Result<Metadata, Error>.failure(
              VerioError("no record available")
            ).publisher
          }

          return Result<Metadata, Error>.success((timeOffset, highestRecordNumber, numberOfRecords)).publisher
        }
        .flatMap(action)
        .ignoreOutput()
        .eraseToAnyPublisher()
      }

      // (1) We first start listening for incoming notifications
      return incomingData
        .compactMap { _ -> [LocalQuantitySample]? in nil }
        .merge(with: output.collect())
        .handleEvents(
          receiveSubscription: { _ in incomingData.connect().store(in: &cancellables) },
          receiveCompletion: { _ in cancellables.forEach { $0.cancel() } },
          receiveCancel: { cancellables.forEach { $0.cancel() } }
        )
        .onStart(
          concat(
            sendCommand(Data([0x20, 0x02]), to: peripheral)
              .tryMap { try parser($0, timeOffsetParser(_:)) }
              .handleEvents(receiveOutput: { timeOffset = $0 })
              .print("Read RTC")
              .ignoreOutput()
              .eraseToAnyPublisher(),
            sendResponseAck(to: peripheral)
              .print("Read RTC ACK")
              .eraseToAnyPublisher(),
            sendCommand(Data([0x0A, 0x02, 0x06]), to: peripheral)
              .tryMap { try parser($0, highestRecordNumberParser(_:)) }
              .handleEvents(receiveOutput: { highestRecordNumber = $0 })
              .print("T counter")
              .ignoreOutput()
              .eraseToAnyPublisher(),
            sendResponseAck(to: peripheral)
              .print("T counter ACK")
              .eraseToAnyPublisher(),
            sendCommand(Data([0x27, 0x00]), to: peripheral)
              .tryMap { try parser($0, numberOfRecordsParser(_:)) }
              .handleEvents(receiveOutput: { numberOfRecords = $0 })
              .print("R counter")
              .ignoreOutput()
              .eraseToAnyPublisher(),
            sendResponseAck(to: peripheral)
              .print("R counter ACK")
              .eraseToAnyPublisher(),
            withCheckedMetadata { metadata in
              // Max 16 entries?
              let requestRange = metadata.highestRecordNumber - min(metadata.numberOfRecords - 1, 15) ... metadata.highestRecordNumber

              return Publishers.Sequence<ClosedRange<Int>, Error>(sequence: requestRange)
                .flatMap(maxPublishers: .max(1)) { index in
                  concat(
                    getRecord(at: index, from: peripheral)
                      .tryMap { try parser($0) { try recordParser($0, timeOffset: metadata.timeOffset) } }
                      .handleEvents(receiveOutput: { output.send($0) })
                      .print("Get Record at \(index)")
                      .ignoreOutput()
                      .eraseToAnyPublisher(),
                    sendResponseAck(to: peripheral)
                      .print("Get Record at \(index) ACK")
                      .eraseToAnyPublisher()
                  )
                }
                .handleEvents(
                  receiveCompletion: { _ in output.send(completion: .finished) }
                )
            }
          )
        )
    }
  }

  func pair(device: ScannedDevice) -> AnyPublisher<Void, Error> {
    _connect(device: device) { (peripheral, command, notification) in
      return Just(()).setFailureType(to: Error.self)
    }
    // Delay completion for 1 second since Verio seem to be non-responsive if we do
    // pair() -> read() in a row with little to no time in between.
    .delay(for: .seconds(1), scheduler: self.queue)
    .eraseToAnyPublisher()
  }

  private func _connect<P>(
    device: ScannedDevice,
    then action: @escaping (Peripheral, _ command: CBCharacteristic, _ notification: CBCharacteristic) -> P
  ) -> AnyPublisher<P.Output, Error> where P: Publisher, P.Failure == Error {
    let isOn = manager
      .didUpdateState
      .prepend(manager.state)
      .filter { $0 == .poweredOn }
      .first()
      .mapError { _ -> Error in }

    return isOn
      .flatMapLatest { _ in self._connectAndDiscoverCharacteristics(for: device, then: action) }
  }


  private func _connectAndDiscoverCharacteristics<P>(
    for device: ScannedDevice,
    then action: @escaping (Peripheral, _ command: CBCharacteristic, _ notification: CBCharacteristic) -> P
  ) -> AnyPublisher<P.Output, Error> where P: Publisher, P.Failure == Error {
    return manager.connect(device.peripheral).flatMapLatest { peripheral -> AnyPublisher<P.Output, Error> in
      peripheral.discoverServices([Self.serviceID])
        .flatMapLatest { services -> AnyPublisher<[CBCharacteristic], Error> in
          guard services.isEmpty == false else {
            return .empty
          }

          return peripheral.discoverCharacteristics([Self.commandCharacteristicID, Self.notificationCharactersiticID], for: services[0])
        }
        .compactMap { characteristics -> (Peripheral, CBCharacteristic, CBCharacteristic)? in
          guard
            let commandCharacteristic = characteristics.first(where: { $0.uuid == Self.commandCharacteristicID }),
            let notificationCharacteristic = characteristics.first(where: { $0.uuid == Self.notificationCharactersiticID })
          else {
            return nil
          }

          return (peripheral, commandCharacteristic, notificationCharacteristic)
        }
        // Take the first valid set of characteristics emitted, and stop the service discovery.
        //
        // This cannot be placed on the outer `.connect()` chain.
        // `first()` cancels its upstream subscription, which means it will cancel `connect()`.
        // `connect()` cancels the CBPeripheral connection when it catches a cancellation.
        .first()
        .flatMapLatest { peripheral, command, notification in
          Publishers.Concatenate(
            // Make sure that we are ready to receive notification
            prefix: peripheral.setNotifyValue(true, for: notification).ignoreOutput().map { _ -> P.Output in },
            suffix: action(peripheral, command, notification)
          )
        }
        .eraseToAnyPublisher()
    }
    .eraseToAnyPublisher()
  }
}

private let verioBaseTime = 946684799

// estimated time zone offset in seconds (integer)
private func timeOffsetParser(_ data: Data) throws -> Int {
  guard data.count == 4 else {
    throw VerioError("RTC should be 4 bytes")
  }

  // NOTE: little endian
  let rtc = Int32(littleEndian: data[0...3])
  let timeInEpoch = Date(timeIntervalSince1970: Double(Int(rtc) + verioBaseTime))
  let offset = Int(Date().timeIntervalSince(timeInEpoch))

  let tolerance = -300 ... 300

  // RTC: floating time but expressed in terms of Unix time
  // Date(): reasonably synchronized UTC time

  // Align to the closest xx:00 hour time zone
  if tolerance.contains(offset % 3600) {
    return offset / 3600 * 3600
  }

  // Align to the closest xx:30 hour time zone
  if tolerance.contains(offset % 1800) {
    return offset / 1800 * 1800
  }

  // Align to the closest xx:15 / xx:45 hour time zone
  return offset / 900 * 900
}

private func highestRecordNumberParser(_ data: Data) throws -> Int {
  guard data.count == 4 else {
    throw VerioError("T counter should be 4 bytes")
  }

  // NOTE: little endian
  return Int(Int32(littleEndian: data[0...3]))
}

private func numberOfRecordsParser(_ data: Data) throws -> Int {
  guard data.count == 2 else {
    throw VerioError("R counter should be 2 bytes")
  }

  // NOTE: little endian
  return Int(Int16(data[1]) << 8 | Int16(data[0]))
}

private func recordParser(_ data: Data, timeOffset: Int) throws -> LocalQuantitySample {
  print("payload: \(data.hex)")

  guard data.count == 11 else {
    throw VerioError("Record should be 11 bytes")
  }

  guard data[6] == 0 && data[8] == 0 && data[9] == 0 && data[10] == 0 else {
    throw VerioError("Invalid record [1]")
  }

  // Byte 7 might be unit indicator
  // But [4...5] is always in mg/dL even on mmol/L models

  let time = Int(Int32(littleEndian: data[0...3])) + verioBaseTime
  let mgdl = Int16(littleEndian: data[4...5])

  // TODO: Ehm, is this timestamp stable?
  return LocalQuantitySample(
    value: Double(mgdl),
    date: Date(timeIntervalSince1970: Double(time)),
    unit: "mg/dL",
    metadata: VitalAnyEncodable([
      "timezone_offset": timeOffset
    ])
  )
}

private func parser<T>(_ data: Data, _ processResult: (Data) throws -> T) throws -> T {
  guard data.count >= 6 else {
    throw VerioError("response too short")
  }

  // Check CRC
  let crc = crc16ccitt(data, skipLastTwo: true, skipFirst: true)
  guard crc == data.suffix(2) else {
    throw VerioError("crc checksum failed")
  }

  guard data[5] == 0x06 else {
    throw VerioError("unsupported response: code = \(data[5...5].hex) | \(data.hex)")
  }

  // Drop 5 byte prefix, 3 byte suffix
  // Then copy the subsequence to rebase the start index to 0
  let result = Data(data.dropFirst(6).dropLast(3))

  return try processResult(Data(result))
}

extension Publisher {
  func onStart<P>(_ publisher: P) -> AnyPublisher<Self.Output, Self.Failure> where P: Publisher, P.Failure == Self.Failure {
    return Deferred {
      var cancellables = Set<AnyCancellable>()
      var hasStarted = false
      let errorInjector = PassthroughSubject<Self.Output, Self.Failure>()

      return handleEvents(
        receiveCompletion: { _ in
          cancellables.forEach { $0.cancel() }
        },
        receiveCancel: {
          cancellables.forEach { $0.cancel() }
        },
        receiveRequest: { demand in
          guard hasStarted == false else { return }
          hasStarted = true

          publisher
            .handleEvents(receiveCancel: { errorInjector.send(completion: .finished) })
            .sink { completion in
              if case let .failure(error) = completion {
                errorInjector.send(completion: .failure(error))
              } else {
                errorInjector.send(completion: .finished)
              }
            } receiveValue: { _ in }
            .store(in: &cancellables)
        }
      )
      .merge(with: errorInjector)
    }
    .eraseToAnyPublisher()
  }
}

internal func packet(_ data: Data) -> Data {
  let packet = Data([0x01]) + dataFrame(data)
  print(packet.hex)
  return packet
}

internal func dataFrame(_ data: Data) -> Data {
  // 3 byte header + delimiter
  // N byte data + delimiter
  let headerAndData = Data([
    0x02,
    UInt8(data.count) + 7,
    0x00,
    0x03, // delimiter
  ]) + data + Data([0x03])

  // 2 byte CRC16
  let crc16 = crc16ccitt(headerAndData)

  return headerAndData + crc16
}


internal func crc16ccitt(_ data: Data, skipLastTwo: Bool = false, skipFirst: Bool = false, initialValue: UInt16 = 0xFFFF) -> Data {
  var crc: UInt16 = initialValue
  let polynomial: UInt16 = 0x1021   // 0001 0000 0010 0001  (0, 5, 12)

  var bytesToProcess = data
  if skipLastTwo {
    bytesToProcess.removeLast(2)
  }
  if skipFirst {
    bytesToProcess.removeFirst()
  }

  for byte in bytesToProcess {
    for i in 0 ..< 8 {
      let bit = (byte >> (7 - i) & 1) == 1
      let c15 = (crc >> 15 & 1) == 1
      crc <<= 1
      if c15 != bit {
        crc ^= polynomial
      }
    }
  }

  crc &= 0xFFFF
  return Data([UInt8(crc & 0xff), UInt8(crc >> 8 & 0xff)])
}

extension Data {
  var hex: String { map { String(format:"%02x", $0) }.joined(separator: " ") }
}

extension FixedWidthInteger {
  init(littleEndian data: Data) {
    let bytes = Self.bitWidth / 8
    precondition(data.count == bytes)
    self = 0
    for index in 0 ..< bytes {
      self |= Self(data[data.startIndex + index]) << (index * 8)
    }
  }
}

func concat(_ publishers: AnyPublisher<Never, Error>...) -> AnyPublisher<Never, Error> {
  Publishers.Sequence(sequence: publishers)
    .flatMap(maxPublishers: .max(1)) { $0 }
    .eraseToAnyPublisher()
}
