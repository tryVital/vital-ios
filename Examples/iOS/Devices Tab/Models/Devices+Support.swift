import VitalDevices
import Foundation

func url(for device: DeviceModel) -> URL {
  
  var image: String
    
  switch device.name {
    case "Omron Intelli IT M4":
      image = "https://storage.googleapis.com/vital-assets/omron_m4.jpeg"
    
    case "Omron Intelli IT M7":
      image = "https://storage.googleapis.com/vital-assets/omron_m7.jpeg"
      
    case "Accu-Chek Guide":
      image = "https://storage.googleapis.com/vital-assets/accu_check_guide.png"
      
    case "Accu-Chek Guide Me":
      image = "https://storage.googleapis.com/vital-assets/accu_chek_guide_me.jpeg"
      
    case "Accu-Chek Active":
      image = "https://storage.googleapis.com/vital-assets/accu_check_active.png"
    
    case "Contour Next One":
      image = "https://storage.googleapis.com/vital-assets/Contour.png"
    
    case "Beurer Devices":
      image = "https://storage.googleapis.com/vital-assets/beurer_devices.png"
      
    case "Freestyle Libre 1":
      image = "https://storage.googleapis.com/vital-assets/libre1.png"
      
    default:
      fatalError("Device not supported")
  }
  
  return URL(string: image)!
}


func name(for deviceKind: DeviceModel.Kind) -> String {
  switch deviceKind {
    case .glucoseMeter:
      return "Glucose Meter"
    case .bloodPressure:
      return "Blood Pressure"
  }
}


extension DeviceModel{
  var isLibre: Bool {
    switch self.brand {
      case .libre:
        return true
      default:
        return false
    }
  }
}
