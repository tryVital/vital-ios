import VitalCore
import CombineCoreBluetooth

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
      
      let write = peripheral.writeValue(Data([1, 1]), for: RACPCharacteristic!, type: .withoutResponse)
      
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
          
          let first = peripheral.setNotifyValue(true, for: characteristics[0])
          let second = peripheral.setNotifyValue(true, for: characteristics[1])
          
          let merged = first.merge(with: second).eraseToAnyPublisher()
          
          return merged.map { _ in
            return (peripheral, characteristics)
          }
          .eraseToAnyPublisher()
        }
    }
    .eraseToAnyPublisher()
  }
}

private func toGlucoseReading(characteristic: CBCharacteristic) -> GlucoseDataPoint? {
  fatalError("Need to Implement")
}

