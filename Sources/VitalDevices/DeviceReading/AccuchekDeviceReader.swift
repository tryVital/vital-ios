import VitalCore
import CombineCoreBluetooth
import Combine

public struct GlucoseDataPoint: Equatable, Hashable {
  public let value: Float
  public let date: Date
  public let units: String
}

public protocol GlucoseMeterReadable: DevicePairable {
  func read(device: ScannedDevice) -> AnyPublisher<GlucoseDataPoint, Error>
}

private let measurementCharacteristicUUID = CBUUID(string: "2A18".fullUUID)
private let RACPCharacteristicUUID = CBUUID(string: "2A52".fullUUID)

class AccuchekDeviceReader: GlucoseMeterReadable {
  
  private let manager: CentralManager

  init(manager: CentralManager = .live()) {
    self.manager = manager
  }
  
  public func read(device: ScannedDevice) -> AnyPublisher<GlucoseDataPoint, Error> {
    return _pair(device: device).flatMapLatest { (peripheral, characteristics) -> AnyPublisher<GlucoseDataPoint, Error> in
      
      let measurementCharacteristic = characteristics.first { $0.uuid == measurementCharacteristicUUID }
      let RACPCharacteristic = characteristics.first { $0.uuid == RACPCharacteristicUUID }
      
      let write = peripheral.writeValue(Data([1, 1]), for: RACPCharacteristic!, type: .withResponse)
      
      return write.flatMapLatest { _ in
        peripheral.listenForUpdates(on: measurementCharacteristic!)
          .compactMap(toGlucoseReading).eraseToAnyPublisher()
      }
    }
  }
  
  public func pair(device: ScannedDevice) -> AnyPublisher<Void, Error> {
    _pair(device: device).map { _ in ()}.eraseToAnyPublisher()
  }
  
  private func _pair(device: ScannedDevice) -> AnyPublisher<(Peripheral, [CBCharacteristic]), Error> {
    let service = DevicesManager.service(for: device.brand)

    
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

extension Date {
    func adding(minutes: Int) -> Date {
        return Calendar.current.date(byAdding: .minute, value: minutes, to: self)!
    }
}

private func toGlucoseReading(characteristic: CBCharacteristic) -> GlucoseDataPoint? {
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

    let components = DateComponents(year: Int(year), month: Int(month), day: Int(day), hour: Int(hour), minute: Int(minute), second: Int(second))
    let date = Calendar.current.date(from: components) ?? .init()
    let correctDate = date.adding(minutes: Int(timeOff))
    let glucose = byteArrayFromData[12]
    return GlucoseDataPoint(value: Float(glucose), date: correctDate, units: "mg/dL")
}
