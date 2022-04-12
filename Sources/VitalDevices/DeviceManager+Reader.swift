import Foundation

public extension DevicesManager {
  
  func bloodPressureReader(for device: ScannedDevice, queue: DispatchQueue = .global()) -> BloodPressureReadable {
    switch device.deviceModel.brand {
    case .omron, .beurer:
        return BloodPressureReader1810(manager: manager, queue: queue)
      default:
        fatalError("\(device.deviceModel.brand) not supported")
    }
  }
  
  func glucoseMeter(for device: ScannedDevice, queue: DispatchQueue = .global()) -> GlucoseMeterReadable {
    switch device.deviceModel.brand {
      case .accuChek, .contour:
        return GlucoseMeter1808(manager: manager, queue: queue)
      default:
        fatalError("\(device.deviceModel.brand) not supported")
    }
  }
}
