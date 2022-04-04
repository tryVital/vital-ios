import Foundation
import CombineCoreBluetooth
import CoreBluetooth


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

public class DevicesManager: ObservableObject {
  private let manager: CentralManager
  var cancellables = Set<AnyCancellable>()
  
  @Published public var peripheralDiscovery: PeripheralDiscovery?
    
  public init() {
    self.manager = .live()
  }
  
  
  public func connect(peripheral: Peripheral) {
    manager.connect(peripheral).flatMap { peripheral -> AnyPublisher<CBCharacteristic, Error> in
      let service = CBUUID(string: fullUUID(value: BLE_BLOOD_PRESSURE_SERVICE))
      let characteristic = CBUUID(string: fullUUID(value: BLE_BLOOD_PRESSURE_MEASURE_CHARACTERISTIC))
      

     let foo =  peripheral.discoverServices([service])
      .flatMap { services -> AnyPublisher<[CBCharacteristic], Error>  in
        peripheral.discoverCharacteristics([characteristic], for: services[0]).eraseToAnyPublisher()
      }.flatMap { characteristic -> AnyPublisher<CBCharacteristic, Error> in
        peripheral.setNotifyValue(true, for: characteristic[0]).eraseToAnyPublisher()
      }
      .flatMap {
        peripheral.listenForUpdates(on: $0)
      }
      .eraseToAnyPublisher()
      
      
      
      
      return foo
    }
    
        .sink(receiveCompletion: {error in
          dump(error)
        }) { (char: CBCharacteristic) in
    
            
//          for char in chars {
            print("\(char.uuid): properties contains .read \(char.properties.contains(.read))")
            print("\(char.uuid): properties contains .notify \(char.properties.contains(.notify))")
            print("\(char.uuid): properties contains .broadcast \(char.properties.contains(.broadcast))")
          
          let value: String? = char.value.map {  String(decoding: $0, as: UTF8.self)}
          
          
          
          print(value ?? "")
//          }

        }
    .store(in: &cancellables)

  }
  
  
  public func startSearch(name: String) {
    manager.scanForPeripherals(withServices: nil)
      .filter { peripheralDiscover in
        peripheralDiscover.peripheral.name?.contains(name) ?? false
      }
      .first()
      .map { Optional($0) }
      .receive(on: DispatchQueue.main)
      .assign(to: \.peripheralDiscovery, on: self) 
      .store(in: &cancellables)
    
    
//    self.manager.scanForPeripherals(withServices: nil, options: .init(allowDuplicates: false, solicitedServiceUUIDs: nil))
//      .filter { (peripheral: PeripheralDiscovery) -> Bool in
//        if peripheral.peripheral.name?.contains("X4 Smart") ?? false {
//          print("==Name =")
//          dump(peripheral.peripheral.name)
//          print("==ServiceUUIDS=")
//          dump(peripheral.advertisementData.serviceUUIDs?[0])
//          print("==AdvetisementData=")
//          dump(peripheral.advertisementData)
//          print("==Services=")
//          dump(peripheral.peripheral.services)
//          return true
//        }
//        else {
//          return false
//        }
//      }
//      .flatMap { peripheral in
//        return self.manager.connect(peripheral.peripheral)
//      }
//      .map(Result.success)
//      .catch({ Just(Result.failure($0)) })
//        .receive(on: DispatchQueue.main)
//        .assign(to: &$peripheralConnectResult)
//
//
//    peripheralConnectResult?.publisher.eraseToAnyPublisher().sink(receiveCompletion: {error in
//      print(error)
//    }) { value in
//      print(value)
//    }
//    .store(in: &cancellables)
//      .flatMap { peripheral -> AnyPublisher<(Peripheral,CBCharacteristic), Error> in
//
//        let service = CBUUID(string: fullUUID(value: BLE_BLOOD_PRESSURE_SERVICE))
//        let characteristic = CBUUID(string: fullUUID(value: BLE_BLOOD_PRESSURE_MEASURE_CHARACTERISTIC))
//
//        ////discoverCharacteristic(withUUID: characteristic, inServiceWithUUID: service)
//        return peripheral.discoverCharacteristic(withUUID: characteristic, inServiceWithUUID: service).map { (peripheral, $0) }.eraseToAnyPublisher()
//      }
//      .flatMap { (peripheral, characteristic) -> AnyPublisher<CBCharacteristic, Error> in
//
//        return peripheral.readValue(for: characteristic)
//      }
//
//    .sink(receiveCompletion: {error in
//      dump(error)
//    }) { value in
//
//
//      dump(value)
//    }
//    .store(in: &cancellables)
  }
}


   
