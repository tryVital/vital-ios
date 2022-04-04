import CombineCoreBluetooth

public struct ScannedDevice {
  public let name: String
  public let uuid: String
  
  private let peripheral: Peripheral
  
  init(
    name: String,
    uuid: String,
    peripheral: Peripheral
  ) {
    self.name = name
    self.uuid = uuid
    self.peripheral = peripheral
  }
}
