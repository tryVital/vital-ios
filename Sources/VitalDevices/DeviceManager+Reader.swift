public extension DevicesManager {
  
  func bloodPressureReader(for device: ScannedDevice) -> BloodPressureReadable {
    switch device.brand {
      case .omron:
        return OmronDeviceReader(manager: manager)
      default:
        fatalError("Not supported")
    }
  }
}
