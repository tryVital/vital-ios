import VitalCore
import CombineCoreBluetooth
import Combine

public protocol GlucoseMeterReadable: DevicePairable {
  func read(device: ScannedDevice) -> AnyPublisher<[LocalQuantitySample], Error>
}

class GlucoseMeter1808: GATTMeter<LocalQuantitySample>, GlucoseMeterReadable {
  init(
    manager: CentralManager = .live(),
    queue: DispatchQueue
  ) {
    super.init(
      manager: manager,
      queue: queue,
      serviceID: CBUUID(string: "1808".fullUUID),
      measurementCharacteristicID: CBUUID(string: "2A18".fullUUID),
      parser: toGlucoseReading(data:),
      didReceiveAll: { scannedDevice, samples in
        postGlucose(scannedDevice.deviceModel.brand.providerSlug, samples: samples)
      }
    )
  }
}

private func toGlucoseReading(data: Data) -> LocalQuantitySample? {
  /// Record size is minimum 10 bytes (all mandatory fields)
  /// Size can vary based on flags encoded in the first byte.
  /// Refer to Bluetooth Glucose Service specification for more information.
  guard data.count >= 10 else {
    return nil
  }

  let bytes: [UInt8] = [UInt8](data)

  let flags: UInt8 = bytes[0]
  let isUnitMolL = (flags & 0x04) != 0
  let isGlucoseDataPresent = (flags & 0x02) != 0
  let isTimeOffsetPresent = (flags & 0x01) != 0

  guard isGlucoseDataPresent else { return nil }

  let sequenceNumber: UInt16 = (UInt16(bytes[2]) << 8) | UInt16(bytes[1])

  // Little-endian
  let year: UInt16 = [bytes[3], bytes[4]].withUnsafeBytes { $0.load(as: UInt16.self) }
  let month = bytes[5]
  let day = bytes[6]
  let hour = bytes[7]
  let minute = bytes[8]
  let second = bytes[9]

  let components = DateComponents(
    year: Int(year),
    month: Int(month),
    day: Int(day),
    hour: Int(hour),
    minute: Int(minute),
    second: Int(second)
  )

  let calendar = Calendar.current
  var date = calendar.date(from: components) ?? .init()

  var offset = 10

  let bleTimeOffset: UInt16?

  if isTimeOffsetPresent {
    let timeOffset = UInt16(bytes[offset + 1]) << 8 | UInt16(bytes[offset])
    date = calendar.date(byAdding: .minute, value: Int(timeOffset), to: date) ?? .init()
    offset += 2
    bleTimeOffset = timeOffset
  } else {
    bleTimeOffset = nil
  }

  let glucoseSFloat = UInt16(bytes[offset + 1]) << 8 | UInt16(bytes[offset])
  offset += 2

  // BLE Glucose Service spec: either kg/L or mol/L.
  let deviceValue = SFloat.read(data: glucoseSFloat)
  let value: Double
  let unit: String

  if isUnitMolL { // mol/L
    value = deviceValue * 1000

  } else { // kg/L
    // 1 mg/dL = 0.0555 mmol/L
    value = deviceValue * 100000 * 0.0555
  }

  return LocalQuantitySample(
    value: value,
    startDate: date,
    endDate: date,
    type: .fingerprick,
    unit: .glucose
  )
}
