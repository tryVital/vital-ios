import VitalCore
import CombineCoreBluetooth

public struct BloodPressureDataPoint: Equatable, Hashable {
  public let systolic: Float
  public let diastolic: Float
  public let pulseRate: Float
  
  public let date: Date
  public let units: String
}

public protocol BloodPressureReadable {
  func pair(device: ScannedDevice) -> AnyPublisher<Void, Error>
  func read(device: ScannedDevice) -> AnyPublisher<BloodPressureDataPoint, Error>
}

class OmronDeviceReader: BloodPressureReadable {
  
  private let manager: CentralManager
  private let BLE_BLOOD_PRESSURE_MEASURE_CHARACTERISTIC = "2A35"
  
  init(manager: CentralManager = .live()) {
    self.manager = manager
  }
  
  
  public func read(device: ScannedDevice) -> AnyPublisher<BloodPressureDataPoint, Error> {
    let service = DevicesManager.service(for: device.brand)
    let characteristic = CBUUID(string: BLE_BLOOD_PRESSURE_MEASURE_CHARACTERISTIC.fullUUID)
    
    return manager.connect(device.peripheral).flatMapLatest { peripheral -> AnyPublisher<BloodPressureDataPoint, Error> in
      
      peripheral.discoverServices([service])
        .flatMapLatest { services -> AnyPublisher<[CBCharacteristic], Error> in
          guard services.isEmpty == false else {
            return .empty
          }
          
          return peripheral.discoverCharacteristics([characteristic], for: services[0])
        }
        .flatMapLatest { characteristics -> AnyPublisher<BloodPressureDataPoint, Error> in
          guard characteristics.isEmpty == false else {
            return .empty
          }
          
          print("===")
          print("Got a reading \(toBloodPressureReading(characteristic: characteristics[0]))")
          
          return peripheral.listenForUpdates(on: characteristics[0]).compactMap(toBloodPressureReading).eraseToAnyPublisher()
        }
    }
    .eraseToAnyPublisher()
  }
    
  public func pair(device: ScannedDevice) -> AnyPublisher<Void, Error> {
    
    let service = DevicesManager.service(for: device.brand)
    let characteristic = CBUUID(string: BLE_BLOOD_PRESSURE_MEASURE_CHARACTERISTIC.fullUUID)
    
    return manager.connect(device.peripheral).flatMapLatest { peripheral -> AnyPublisher<Void, Error> in
      
      peripheral.discoverServices([service])
        .flatMapLatest { services -> AnyPublisher<[CBCharacteristic], Error> in
          guard services.isEmpty == false else {
            return .empty
          }
          
          return peripheral.discoverCharacteristics([characteristic], for: services[0])
        }
        .flatMapLatest { characteristics -> AnyPublisher<Void, Error> in
          guard characteristics.isEmpty == false else {
            return .empty
          }
          
          return peripheral.setNotifyValue(true, for: characteristics[0]).map { _ in () }.eraseToAnyPublisher()
        }
    }
    .eraseToAnyPublisher()
  }
}
  
private func toBloodPressureReading(characteristic: CBCharacteristic) -> BloodPressureDataPoint? {
  guard let data = characteristic.value else {
    return nil
  }
  
  let byteArrayFromData: [UInt8] = [UInt8](data)
  
  let units = (byteArrayFromData[0] & 1) != 0 ? "kPa" : "mmHg"
  
  let systolic: UInt16 = [byteArrayFromData[1], byteArrayFromData[2]].withUnsafeBytes { $0.load(as: UInt16.self) }
  let diastolic: UInt16 = [byteArrayFromData[3], byteArrayFromData[4]].withUnsafeBytes { $0.load(as: UInt16.self) }

  let year: UInt16 = [byteArrayFromData[7], byteArrayFromData[8]].withUnsafeBytes { $0.load(as: UInt16.self) }
  let month = byteArrayFromData[9]
  let day = byteArrayFromData[10]
  let hour = byteArrayFromData[11]
  let minute = byteArrayFromData[12]
  let second = byteArrayFromData[13]
  
  let components = DateComponents(year: Int(year), month: Int(month), day: Int(day), hour: Int(hour), minute: Int(minute), second: Int(second))
  let date = Calendar.current.date(from: components) ?? .init()
  
  let pulseRate: UInt16 = [byteArrayFromData[14], byteArrayFromData[15]].withUnsafeBytes { $0.load(as: UInt16.self) }
  
  return BloodPressureDataPoint(
    systolic: Float(systolic),
    diastolic: Float(diastolic),
    pulseRate: Float(pulseRate),
    date: date,
    units: units
  )
}
