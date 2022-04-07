public extension DevicesManager {
  
  func bloodPressureReader(for device: ScannedDevice) -> BloodPressureReadable {
    switch device.brand {
      case .omron:
        return BloodPressureReader1810(manager: manager)
      default:
        fatalError("\(device.brand) not supported")
    }
  }
  
  func glucoseMeter(for device: ScannedDevice) -> GlucoseMeterReadable {
    switch device.brand {
      case .accuCheck, .contour:
        return GlucoseMeter1808(manager: manager)
      default:
        fatalError("\(device.brand) not supported")
    }
  }
}
