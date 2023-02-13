import VitalCore
import CombineCoreBluetooth
import Combine

public protocol GlucoseMeterReadable: DevicePairable {
  func read(device: ScannedDevice) -> AnyPublisher<[QuantitySample], Error>
}

private let service = CBUUID(string: "1808")
private let measurementCharacteristicUUID = CBUUID(string: "2A18".fullUUID)
private let RACPCharacteristicUUID = CBUUID(string: "2A52".fullUUID)

class GlucoseMeter1808: GlucoseMeterReadable {
  
  private let manager: CentralManager
  private let queue: DispatchQueue
  
  init(manager: CentralManager = .live(), queue: DispatchQueue) {
    self.manager = manager
    self.queue = DispatchQueue(label: "co.tryvital.VitalDevices.GlucoseMeter1808", target: queue)
  }

  func read(device: ScannedDevice) -> AnyPublisher<[QuantitySample], Error> {
    return _pair(device: device).flatMapLatest { (peripheral, characteristics) -> AnyPublisher<[QuantitySample], Error> in
        guard
          let measurementCharacteristic = characteristics.first(where: { $0.uuid == measurementCharacteristicUUID }),
          let RACPCharacteristic = characteristics.first(where: { $0.uuid == RACPCharacteristicUUID })
        else {
          return Fail(outputType: [QuantitySample].self, failure: BluetoothError(message: "Missing required characteristics."))
            .eraseToAnyPublisher()
        }
        var cancellables: Set<AnyCancellable> = []

        let write = peripheral.writeValue(Data([1, 1]), for: RACPCharacteristic, type: .withResponse)

        let racpResponse = CurrentValueSubject<RACPResponse?, Error>(nil)
        let racpSuccessOrFailure = racpResponse.compactMap { $0 }.first().tryMap { response in
          switch response {
          case .success, .noRecordsFound:
            return ()
          case .notCompleted, .unknown, .invalidPayloadStructure:
            throw BluetoothRACPError(code: response.code)
          }
        }

        // (1) We first start listening for measurement notifications
        return peripheral
          .listenForUpdates(on: measurementCharacteristic)
          .compactMap(toGlucoseReading)
          .prefix(untilOutputFrom: racpSuccessOrFailure)
          .collect()
          .handleEvents(
            receiveSubscription: { _ in
              // (2) We then start listening for RACP response indication
              peripheral
                .listenForUpdates(on: RACPCharacteristic)
                .map { $0.map(RACPResponse.init) ?? .invalidPayloadStructure }
                .subscribe(racpResponse)
                .store(in: &cancellables)

              // (3) We finally write to RACP to initiate the Load All Records operation.
              write
                .sink(receiveCompletion: { _ in }, receiveValue: {})
                .store(in: &cancellables)
            },
            receiveCompletion: { _ in
              cancellables.forEach { $0.cancel() }
            },
            receiveCancel: {
              cancellables.forEach { $0.cancel() }
            }
          )
          .eraseToAnyPublisher()
    }
  }

  func pair(device: ScannedDevice) -> AnyPublisher<Void, Error> {
    _pair(device: device).map { _ in ()}.eraseToAnyPublisher()
  }
  
  private func _pair(device: ScannedDevice) -> AnyPublisher<(Peripheral, [CBCharacteristic]), Error> {
    let isOn: AnyPublisher<CBManagerState, Error> = manager
      .didUpdateState.filter { state in
        state == .poweredOn
      }
      .mapError { _ -> Error in }
      .eraseToAnyPublisher()
    
    if manager.state == .poweredOn {
      return GlucoseMeter1808._pair(
        manager: manager,
        device: device,
        measurementCharacteristicUUID: measurementCharacteristicUUID,
        RACPCharacteristicUUID: RACPCharacteristicUUID
      )
    } else {
      return isOn.flatMapLatest { [manager] _ in
        return GlucoseMeter1808._pair(
          manager: manager,
          device: device,
          measurementCharacteristicUUID: measurementCharacteristicUUID,
          RACPCharacteristicUUID: RACPCharacteristicUUID
        )
      }
    }
  }
  
  private static func _pair(
    manager: CentralManager,
    device: ScannedDevice,
    measurementCharacteristicUUID: CBUUID,
    RACPCharacteristicUUID: CBUUID
  ) -> AnyPublisher<(Peripheral, [CBCharacteristic]), Error> {
    return manager.connect(device.peripheral).flatMapLatest { peripheral -> AnyPublisher<(Peripheral, [CBCharacteristic]), Error> in
      peripheral.discoverServices([service])
        .flatMapLatest { services -> AnyPublisher<[CBCharacteristic], Error> in
          guard services.isEmpty == false else {
            return .empty
          }
          
          return peripheral.discoverCharacteristics([measurementCharacteristicUUID, RACPCharacteristicUUID], for: services[0])
        }
        .flatMapLatest { characteristics -> AnyPublisher<(Peripheral, [CBCharacteristic]), Error> in
          guard characteristics.count == 2 else {
            return .empty
          }
          let second = peripheral.setNotifyValue(true, for: characteristics[1])
          let first = peripheral.setNotifyValue(true, for: characteristics[0])

          let zipped = first.zip(second).first().eraseToAnyPublisher()
          
          return zipped.map { _ in
            return (peripheral, characteristics)
          }
          .eraseToAnyPublisher()
        }
    }
    .eraseToAnyPublisher()
  }
}

private func toGlucoseReading(data: Data?) -> QuantitySample? {
  guard let data = data, data.count >= 10 else {
    return nil
  }

  let bytes: [UInt8] = [UInt8](data)

  let flags: UInt8 = bytes[0]
  let isUnitMolL = (flags & 0x04) != 0
  let isGlucoseDataPresent = (flags & 0x02) != 0
  let isTimeOffsetPresent = (flags & 0x01) != 0

  guard isGlucoseDataPresent else { return nil }

  let sequenceNumber: UInt16 = (UInt16(bytes[2]) << 8) | UInt16(bytes[1])

  let year: UInt16 = [bytes[3], bytes[4]].withUnsafeBytes { $0.load(as: UInt16.self) }
  let month = bytes[5]
  let day = bytes[6]
  let hour = bytes[7]
  let minute = bytes[8]
  let second = bytes[9]

  let components = DateComponents(
    year: Int(year),
    month: Int(month),
    day: Int(day),
    hour: Int(hour),
    minute: Int(minute),
    second: Int(second)
  )

  let calendar = Calendar.current
  var date = calendar.date(from: components) ?? .init()

  var offset = 10

  if isTimeOffsetPresent {
    let timeOffset = UInt16(bytes[offset + 1]) << 8 | UInt16(bytes[offset])
    date = calendar.date(byAdding: .minute, value: Int(timeOffset), to: date) ?? .init()
    offset += 2
  }

  let glucoseSFloat = UInt16(bytes[offset + 1]) << 8 | UInt16(bytes[offset])
  offset += 2

  // BLE Glucose Service spec: either kg/L or mol/L.
  let deviceValue = SFloat.read(data: glucoseSFloat)
  let value: Double
  let unit: String

  if isUnitMolL { // mol/L
    value = deviceValue * 1000
    unit = "mmol/L"
  } else { // kg/L
    value = deviceValue * 100000
    unit = "mg/dL"
  }

  return QuantitySample(
    id: "\(sequenceNumber)",
    value: value,
    startDate: date,
    endDate: date,
    type: "fingerprick",
    unit: unit
  )
}
