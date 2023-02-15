import Foundation
import CombineCoreBluetooth
import CoreBluetooth

public class DevicesManager {
  lazy var manager: CentralManager = .live()
  
  public init() {}
  
  public func search(
    for deviceModel: DeviceModel
  ) -> AnyPublisher<ScannedDevice, Never> {
    if manager.state == .poweredOn {
      return DevicesManager._search(manager: manager, deviceModel: deviceModel)
    } else {
      return manager
        .didUpdateState.filter { state in
          state == .poweredOn
        }
        .eraseToAnyPublisher()
        .flatMapLatest{[manager] _ in
          DevicesManager._search(manager: manager, deviceModel: deviceModel)
        }
    }
  }
  
  private static func _search(
    manager: CentralManager,
    deviceModel: DeviceModel
  ) -> AnyPublisher<ScannedDevice, Never> {
    let service = Self.service(for: deviceModel.brand)

    return manager
      .scanForPeripherals(withServices: [service])
      .compactMap { peripheralDiscover in
        guard let name = peripheralDiscover.peripheral.name else {
          return nil
        }
        
        let codes = DevicesManager.codes(for: deviceModel.id)

        let lowercasedName = name.lowercased()
        let outcome = codes.contains { lowercasedName.contains($0.lowercased()) }
          || codes.contains(Self.vitalBLESimulator)

        guard outcome else {
          return nil
        }
        
        return peripheralDiscover.peripheral
      }
      .map { (peripheral: Peripheral) -> ScannedDevice in
        ScannedDevice(
          id: peripheral.id,
          name: peripheral.name!,
          deviceModel: deviceModel,
          peripheral: peripheral
        )
      }
      .eraseToAnyPublisher()
  }
  
  public func monitorConnection(for device: ScannedDevice) -> AnyPublisher<Bool, Never> {
    manager.monitorConnection(for: device.peripheral).eraseToAnyPublisher()
  }
}
