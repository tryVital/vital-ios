import CombineCoreBluetooth

public struct ScannedDevice: Equatable {
  public let name: String
  public let uuid: String
  
  let brand: Brand
  let peripheral: Peripheral
  
  init(
    name: String,
    uuid: String,
    brand: Brand,
    peripheral: Peripheral
  ) {
    self.name = name
    self.uuid = uuid
    self.brand = brand
    self.peripheral = peripheral
  }
}
