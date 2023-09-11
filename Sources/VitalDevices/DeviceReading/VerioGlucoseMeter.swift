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

  func read(device: ScannedDevice) -> AnyPublisher<[QuantitySample], Error> {
    return _connect(device: device) { (peripheral, command, notification) -> AnyPublisher<[QuantitySample], Error> in
      let incomingData = peripheral
        .listenForUpdates(on: notification)
        .compactMap { $0 }
        .print("Data")
        .multicast(subject: PassthroughSubject())

      let output = PassthroughSubject<[QuantitySample], Error>()

      func sendCommand(_ data: Data, to peripheral: Peripheral) -> AnyPublisher<Data, Error> {
        incomingData
          // Listen for the ACK byte and then drop it
          // The next delivery after the ACK byte is the actual command response
          .drop(while: { ($0.first ?? 0x00) & 0x81 != 0x81 })
          .dropFirst(1)
          .first()
          .onStart(
            peripheral.writeValue(packet(data), for: command, type: .withoutResponse)
          )
          .eraseToAnyPublisher()
      }

      func sendResponseAck(to peripheral: Peripheral) -> AnyPublisher<Never, Error> {
        peripheral.writeValue(packet(Data([0x81])), for: command, type: .withoutResponse)
          .ignoreOutput()
          .eraseToAnyPublisher()
      }

      var cancellables = Set<AnyCancellable>()

      // (1) We first start listening for incoming notifications
      return incomingData
        .compactMap { _ -> [QuantitySample]? in nil }
        .merge(with: output)
        .handleEvents(
          receiveSubscription: { _ in incomingData.connect().store(in: &cancellables) },
          receiveCompletion: { _ in cancellables.forEach { $0.cancel() } },
          receiveCancel: { cancellables.forEach { $0.cancel() } }
        )
        .onStart(
          Publishers.Sequence(sequence: [
            sendCommand(Data([0x20, 0x02]), to: peripheral)
              .tryMap { try parser($0, timeOffsetParser(_:)) }
              .print("Read RTC")
              .ignoreOutput()
              .eraseToAnyPublisher(),
            sendResponseAck(to: peripheral)
              .print("Read RTC ACK")
              .eraseToAnyPublisher(),
            sendCommand(Data([0x0A, 0x02, 0x06]), to: peripheral)
              .tryMap { try parser($0, highestRecordNumberParser(_:)) }
              .print("T counter")
              .ignoreOutput()
              .eraseToAnyPublisher(),
            sendResponseAck(to: peripheral)
              .print("T counter ACK")
              .eraseToAnyPublisher(),
            sendCommand(Data([0x27, 0x00]), to: peripheral)
              .tryMap { try parser($0, numberOfRecordsParser(_:)) }
              .print("R counter")
              .ignoreOutput()
              .eraseToAnyPublisher(),
            sendResponseAck(to: peripheral)
              .print("R counter ACK")
              .eraseToAnyPublisher(),
          ])
          .flatMap(maxPublishers: .max(1)) { publisher in publisher }
        )
    }
  }

  func pair(device: ScannedDevice) -> AnyPublisher<Void, Error> {
    _connect(device: device) { (peripheral, command, notification) in
      return Just(()).setFailureType(to: Error.self)
    }
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

// positive: ahead of UTC
// negative: behind UTC
//
// returns: time offset in seconds (integer)
private func timeOffsetParser(_ data: Data) throws -> Int {
  guard data.count == 4 else {
    throw VerioError("RTC should be 4 bytes")
  }

  // NOTE: little endian
  let rtc = Int32(data[3]) << 24 | Int32(data[2]) << 16 | Int32(data[1]) << 8 | Int32(data[0])
  let timeInEpoch = Date(timeIntervalSince1970: Double(Int(rtc) + verioBaseTime))

  return Int(Date().timeIntervalSince(timeInEpoch))
}

private func highestRecordNumberParser(_ data: Data) throws -> Int {
  guard data.count == 4 else {
    throw VerioError("T counter should be 4 bytes")
  }

  // NOTE: little endian
  return Int(Int32(data[3]) << 24 | Int32(data[2]) << 16 | Int32(data[1]) << 8 | Int32(data[0]))
}

private func numberOfRecordsParser(_ data: Data) throws -> Int {
  guard data.count == 2 else {
    throw VerioError("R counter should be 2 bytes")
  }

  // NOTE: little endian
  return Int(Int16(data[1]) << 8 | Int16(data[0]))
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
  func onStart<P>(_ publisher: P) -> AnyPublisher<Self.Output, Self.Failure> where P: Publisher {
    return Deferred {
      var cancellables = Set<AnyCancellable>()
      var hasStarted = false

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
            .sink { _ in } receiveValue: { _ in }
            .store(in: &cancellables)
        }
      )
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
