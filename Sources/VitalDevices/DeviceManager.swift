import Foundation
import CombineCoreBluetooth
import CoreBluetooth

let identifier = "575E3154-5E9A-217F-DAFF-5115D1291AB2"
let BLE_BLOOD_PRESSURE_SERVICE = "1810"
let BLE_BLOOD_PRESSURE_MEASURE_CHARACTERISTIC = "2A35"
let BLOOD_PRESSURE_UNITS = 1;

public class DevicesManager: ObservableObject {
  private let manager: CentralManager

  public init() {
    self.manager = .live()
  }
  
  public func startSearch(
    for deviceModel: DeviceModel
  ) -> AnyPublisher<ScannedDevice, Never> {
    
    let service = Self.service(for: deviceModel.brand)
    
    return manager
      .scanForPeripherals(withServices: [service])
      .compactMap { peripheralDiscover in
        guard let name = peripheralDiscover.peripheral.name else {
          return nil
        }
        
        let outcome = deviceModel.codes.reduce(false) { partialResult, code in
          guard partialResult == false else {
            return true
          }
          
          return name.contains(code)
        }
        
        guard outcome else {
          return nil
        }
        
        return peripheralDiscover.peripheral
      }
      .map { (peripheral: Peripheral) -> ScannedDevice in
        ScannedDevice(
          name: peripheral.name!,
          uuid: peripheral.id.uuidString,
          peripheral: peripheral
        )
      }
      .eraseToAnyPublisher()
  }
  
//  public func connect(device: ScannedDevice) {
//    
//    manager.connect(peripheral).flatMap { peripheral -> AnyPublisher<CBCharacteristic, Error> in
//      let service = CBUUID(string: fullUUID(value: BLE_BLOOD_PRESSURE_SERVICE))
//      let characteristic = CBUUID(string: fullUUID(value: BLE_BLOOD_PRESSURE_MEASURE_CHARACTERISTIC))
//      
//      
//      return peripheral.discoverServices([service])
//        .flatMap { services -> AnyPublisher<[CBCharacteristic], Error>  in
//          peripheral.discoverCharacteristics([characteristic], for: services[0]).eraseToAnyPublisher()
//        }.flatMap { characteristic -> AnyPublisher<CBCharacteristic, Error> in
//          peripheral.setNotifyValue(true, for: characteristic[0]).eraseToAnyPublisher()
//        }
//        .flatMap {
//          peripheral.listenForUpdates(on: $0)
//        }
//        .eraseToAnyPublisher()
//    }
//    
//    .sink(receiveCompletion: {error in
//      dump(error)
//    }) { (char: CBCharacteristic) in
//      
//      
//      //          for char in chars {
//      print("\(char.uuid): properties contains .read \(char.properties.contains(.read))")
//      print("\(char.uuid): properties contains .notify \(char.properties.contains(.notify))")
//      print("\(char.uuid): properties contains .broadcast \(char.properties.contains(.broadcast))")
//      
//      let value: String? = char.value.map { self.convertFromBase64(data: $0) }
//      
//            
//      print(value ?? "")
//      //          }
//      
//    }
//    .store(in: &cancellables)
//    
//  }
//  
//  
//  func convertFromBase64(data: Data) -> String {
//    let byteArrayFromData: [UInt8] = [UInt8](data)
//        
//    let flag = (byteArrayFromData[0] & 1) != 0 ? "kPa" : "mmHg"
//    
//    
//    let year: UInt16 = [byteArrayFromData[7], byteArrayFromData[8]].withUnsafeBytes { $0.load(as: UInt16.self) }
//    let month = byteArrayFromData[9]
//    let day = byteArrayFromData[10]
//    let hour = byteArrayFromData[11]
//    let minutes = byteArrayFromData[12]
//    let second = byteArrayFromData[13]
//    
//    let pulseRate: UInt16 = [byteArrayFromData[14], byteArrayFromData[15]].withUnsafeBytes { $0.load(as: UInt16.self) }
//    let userIndex = byteArrayFromData[16]
//    
//    
//    return ""
//  }
  

}



