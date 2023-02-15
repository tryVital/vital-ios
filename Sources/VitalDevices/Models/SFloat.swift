import Foundation

internal enum SFloat {
  enum ReservedValue: Int16 {
    case positiveInfinity = 0x07FE
    case nan = 0x07FF
    case nres = 0x0800
    case reservedValue = 0x0801
    case negativeInfinity = 0x0802

    var doubleValue: Double {
      switch self {
      case .positiveInfinity:
        return .infinity
      case .negativeInfinity:
        return -.infinity
      case .reservedValue, .nres, .nan:
        return .nan
      }
    }
  }

  static func read(data: UInt16) -> Double {
    var mantissa = Int16(data & 0x0FFF)
    var expoent = Int8(data >> 12)

    if let reservedValue = ReservedValue(rawValue: mantissa) {
      return reservedValue.doubleValue
    }

    if expoent >= 0x0008 {
      expoent = -((0x000F + 1) - expoent)
    }

    if mantissa >= 0x0800 {
      mantissa = -((0x0FFF + 1) - mantissa)
    }

    let magnitude = pow(10.0, Double(expoent))
    return Double(mantissa) * magnitude
  }
}
