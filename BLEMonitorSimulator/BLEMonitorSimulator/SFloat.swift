import Foundation

extension BinaryInteger {
  func data(bytes: UInt8) -> Data {
    let byteCount = bitWidth / 8
    precondition(bytes == byteCount)

    return withUnsafeTemporaryAllocation(byteCount: byteCount, alignment: byteCount) { buffer in
      buffer.baseAddress!.withMemoryRebound(to: Self.self, capacity: 1) { address in
        address.initialize(to: self)
      }

      return Data(bytes: buffer.baseAddress!, count: buffer.count)
    }
  }
}

enum SFloat {
  enum ReservedValue: Int16 {
    case positiveInfinity = 0x07FE
    case nan = 0x07FF
    case nres = 0x0800
    case reservedValue = 0x0801
    case negativeInfinity = 0x0802

    static func contains(_ value: Int16) -> Bool {
      positiveInfinity.rawValue <= value && value <= negativeInfinity.rawValue
    }

    static func infinity(_ sign: FloatingPointSign) -> Self {
      switch sign {
      case .plus:
        return .positiveInfinity
      case .minus:
        return .negativeInfinity
      }
    }

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

  /// (2^11 - 3) * 10^7
  static let max: Double = 20450000000.0

  /// -(2^11 - 3) * 10^7
  static let min: Double = -max

  /// 2^11 - 3
  static let mantissaMax: Double = 0x07FD

  /// 2^3 - 1
  static let exponentMax: Int16 = 7

  /// -2^3
  static let exponentMin: Int16 = -8

  /// 10^-8
  static let epsilon: Double = 1e-8

  /// 10 ^ upper(11 * log(2) / log(10))
  static let precision: UInt32 = 10000


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


  static func write(value: Double) -> UInt16 {
    guard !value.isNaN else { return UInt16(ReservedValue.nan.rawValue) }
    guard value <= max else { return UInt16(ReservedValue.positiveInfinity.rawValue) }
    guard min <= value else { return UInt16(ReservedValue.negativeInfinity.rawValue) }
    guard value < -epsilon || epsilon < value else { return 0 }

    let sign = value > 0.0 ? 1.0 : -1.0
    var mantissa = abs(value)
    var exponent: Int16 = 0 // Exponent of 10

    // Scale up if the number is too large.
    while (mantissa > mantissaMax) {
      mantissa /= 10.0
      exponent += 1

      if (exponent > exponentMax) {
        return UInt16(ReservedValue.infinity(value.sign).rawValue)
      }
    }

    // Scale down if the number is too small.
    while (mantissa < 1) {
      mantissa *= 10
      exponent -= 1

      if (exponent < exponentMin) {
        return 0
      }
    }

    // Scale down if the number needs more precision.
    let precision = Double(Self.precision)
    var smantissa = (mantissa * precision).rounded()
    var rmantissa = mantissa.rounded() * precision
    var mdiff = abs(smantissa - rmantissa)

    while mdiff > 0.5, exponentMin < exponent, (mantissa * 10) <= mantissaMax {
      mantissa *= 10
      exponent -= 1
      smantissa = (mantissa * precision).rounded()
      rmantissa = mantissa.rounded() * precision
      mdiff = abs(smantissa - rmantissa)
    }

    let finalMantissa = Int16((sign * mantissa).rounded())
    return UInt16(bitPattern: (exponent & 0xF) << 12) | UInt16(bitPattern: (finalMantissa & 0xFFF))
  }
}
