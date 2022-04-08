public extension DevicesManager {
  
  func bloodPressureReader(for device: ScannedDevice) -> BloodPressureReadable {
    switch device.deviceModel.brand {
      case .omron:
        return BloodPressureReader1810(manager: manager)
      default:
        fatalError("\(device.deviceModel.brand) not supported")
    }
  }
  
  func glucoseMeter(for device: ScannedDevice) -> GlucoseMeterReadable {
    switch device.deviceModel.brand {
      case .accuCheck, .contour:
        return GlucoseMeter1808(manager: manager)
      default:
        fatalError("\(device.deviceModel.brand) not supported")
    }
  }
}
