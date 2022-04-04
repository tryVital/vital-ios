import Foundation
import CombineCoreBluetooth


func fullUUID(value: String) -> String {
  let suffix =  "-0000-1000-8000-00805f9b34fb"
  if value.count == 4 {
    return "0000" + value.lowercased() + suffix
  }
  
  if value.count == 8 {
    return value.lowercased() + suffix
  }
      
  return value
}

let identifier = "575E3154-5E9A-217F-DAFF-5115D1291AB2"
let BLE_BLOOD_PRESSURE_SERVICE = "1810"
let BLE_BLOOD_PRESSURE_MEASURE_CHARACTERISTIC = "2A35"
let BLOOD_PRESSURE_UNITS = 1;

public class DevicesManager {
  private let manager: CentralManager
  var cancellables = Set<AnyCancellable>()
  
  public init() {
    self.manager = .live()
  }
  
  
  public func startSearch() {
    self.manager.scanForPeripherals(withServices: nil, options: nil)
      .filter { (peripheral: PeripheralDiscovery) -> Bool in
        if peripheral.peripheral.name?.contains("X4 Smart") ?? false {
          print("==Name =")
          dump(peripheral.peripheral.name)
          print("==ServiceUUIDS=")
          dump(peripheral.advertisementData.serviceUUIDs?[0])
          print("==AdvetisementData=")
          dump(peripheral.advertisementData)
          print("==Services=")
          dump(peripheral.peripheral.services)
          return true
        }
        else {
          return false
        }
      }
      .flatMap { peripheral in
        return self.manager.connect(peripheral.peripheral)
      }
      .flatMap { peripheral -> AnyPublisher<(Peripheral, [CBService]), Error> in
                
        let service = CBUUID(string: fullUUID(value: BLE_BLOOD_PRESSURE_SERVICE))
        let characteristic = CBUUID(string: fullUUID(value: BLE_BLOOD_PRESSURE_MEASURE_CHARACTERISTIC))
        
        ////discoverCharacteristic(withUUID: characteristic, inServiceWithUUID: service)
        return peripheral.discoverServices([service]).map { (peripheral, $0) }.eraseToAnyPublisher()
      }
//      .flatMap { (peripheral, services) in
//        print(services)
//
//        return peripheral.readValue(for: characteristic)
//      }
    
    .sink(receiveCompletion: {error in
      dump(error)
    }) { value in
      
    
      dump(value)
    }
    .store(in: &cancellables)
  }
}
