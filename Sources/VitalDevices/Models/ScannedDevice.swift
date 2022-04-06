import CombineCoreBluetooth

public struct ScannedDevice: Equatable {
  public let name: String
  public let uuid: String
  public let brand: Brand
  public let kind: DeviceModel.Kind

  let peripheral: Peripheral
  
  init(
    name: String,
    uuid: String,
    brand: Brand,
    kind: DeviceModel.Kind,
    peripheral: Peripheral
  ) {
    self.name = name
    self.uuid = uuid
    self.brand = brand
    self.kind = kind
    self.peripheral = peripheral
  }
}
