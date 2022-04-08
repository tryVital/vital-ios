import CombineCoreBluetooth

public struct ScannedDevice: Equatable {
  public let id: UUID
  public let name: String
  public let deviceModel: DeviceModel
  
  let peripheral: Peripheral
  
  init(
    id: UUID,
    name: String,
    deviceModel: DeviceModel,
    peripheral: Peripheral
  ) {
    self.id = id
    self.name = name
    self.deviceModel = deviceModel
    self.peripheral = peripheral
  }
}
