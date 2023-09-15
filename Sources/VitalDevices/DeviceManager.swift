import Foundation
import CombineCoreBluetooth
import CoreBluetooth

public class DevicesManager {
  lazy var manager: CentralManager = .live()
  
  public init() {}

  public func connected(_ deviceModel: DeviceModel) -> [ScannedDevice] {
    let service = Self.service(for: deviceModel.brand)

    return manager
      .retrieveConnectedPeripherals(withServices: [service])
      .compactMap { Self.suitableScannedDevice(from: $0, for: deviceModel) }
  }

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
    let service = Self.advertisementService(for: deviceModel.brand)

    return manager
      .scanForPeripherals(withServices: service.map { [$0] })
      .compactMap { peripheralDiscover in
        Self.suitableScannedDevice(from: peripheralDiscover.peripheral, for: deviceModel)
      }
      .eraseToAnyPublisher()
  }
  
  public func monitorConnection(for device: ScannedDevice) -> AnyPublisher<Bool, Never> {
    manager.monitorConnection(for: device.peripheral).eraseToAnyPublisher()
  }

  static func suitableScannedDevice(from peripheral: Peripheral, for deviceModel: DeviceModel) -> ScannedDevice? {
    guard let name = peripheral.name else {
      return nil
    }

    let codes = DevicesManager.codes(for: deviceModel.id)

    let lowercasedName = name.lowercased()
    let outcome = codes.contains { lowercasedName.contains($0.lowercased()) }
      || codes.contains(Self.vitalBLESimulator)

    guard outcome else {
      return nil
    }

    return ScannedDevice(
      id: peripheral.id,
      name: peripheral.name!,
      deviceModel: deviceModel,
      peripheral: peripheral
    )
  }
}
