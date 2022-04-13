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
    self.queue = queue    
  }
  
  public func read(device: ScannedDevice) -> AnyPublisher<[QuantitySample], Error> {
    return _pair(device: device).flatMapLatest { (peripheral, characteristics) -> AnyPublisher<[QuantitySample], Error> in
      
      let measurementCharacteristic = characteristics.first { $0.uuid == measurementCharacteristicUUID }
      let RACPCharacteristic = characteristics.first { $0.uuid == RACPCharacteristicUUID }
      
      let write = peripheral.writeValue(Data([1, 1]), for: RACPCharacteristic!, type: .withResponse)
      
      return write.flatMapLatest { _ in
        peripheral.listenForUpdates(on: measurementCharacteristic!)
          .compactMap(toGlucoseReading)
      }
      .collect(.byTimeOrCount(self.queue, 3.0, 50))
      .eraseToAnyPublisher()
    }
  }
  
  public func pair(device: ScannedDevice) -> AnyPublisher<Void, Error> {
    _pair(device: device).map { _ in ()}.eraseToAnyPublisher()
  }
  
  private func _pair(device: ScannedDevice) -> AnyPublisher<(Peripheral, [CBCharacteristic]), Error> {
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
          
          let zipped = first.zip(second).eraseToAnyPublisher()
          
          return zipped.map { _ in
            return (peripheral, characteristics)
          }
          .eraseToAnyPublisher()
        }
    }
    .eraseToAnyPublisher()
  }
}

private func toGlucoseReading(characteristic: CBCharacteristic) -> QuantitySample? {
  guard let data = characteristic.value else {
    return nil
  }
  let byteArrayFromData: [UInt8] = [UInt8](data)
  let record: UInt16 = [byteArrayFromData[1], byteArrayFromData[2]].withUnsafeBytes { $0.load(as: UInt16.self) }
  let year: UInt16 = [byteArrayFromData[3], byteArrayFromData[4]].withUnsafeBytes { $0.load(as: UInt16.self) }
  let month = byteArrayFromData[5]
  let day = byteArrayFromData[6]
  let hour = byteArrayFromData[7]
  let minute = byteArrayFromData[8]
  let second = byteArrayFromData[9]
  let timeOff = [byteArrayFromData[10], byteArrayFromData[11]].withUnsafeBytes { $0.load(as: UInt16.self) }
  
  let components = DateComponents(
    year: Int(year),
    month: Int(month),
    day: Int(day),
    hour: Int(hour),
    minute: Int(minute),
    second: Int(second)
  )
  
  let calendar = Calendar.current
  let date = calendar.date(from: components) ?? .init()
  let correctedDate = calendar.date(byAdding: .minute, value:  Int(timeOff), to: date) ?? .init()
  
  let glucose = byteArrayFromData[12]
  
  return QuantitySample(
    value: Double(glucose),
    startDate: correctedDate,
    endDate: correctedDate,
    type: "fingerprick",
    unit: "mg/dL"
  )
}
