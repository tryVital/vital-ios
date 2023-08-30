import VitalCore
import CombineCoreBluetooth

public protocol BloodPressureReadable: DevicePairable {
  func read(device: ScannedDevice) -> AnyPublisher<[BloodPressureSample], Error>
}

class BloodPressureReader1810: GATTMeterWithNoRACP<BloodPressureSample>, BloodPressureReadable {
  init(
    manager: CentralManager = .live(),
    queue: DispatchQueue
  ) {
    super.init(
      manager: manager,
      queue: queue,
      serviceID: CBUUID(string: "1810".fullUUID),
      // Blood Pressure Measurement characteristic
      measurementCharacteristicID: CBUUID(string: "2A35".fullUUID),
      parser: toBloodPressureReading(data:)
    )
  }
}

private func toBloodPressureReading(data: Data) -> BloodPressureSample? {
  guard data.count >= 1 else { return nil }

  let bytes: [UInt8] = [UInt8](data)
  let isTimestampPresent = (bytes[0] & 0x02) != 0
  let isPulseRatePresent = (bytes[0] & 0x04) != 0

  let expectedPayloadSize = 14 + (isPulseRatePresent ? 2 : 0)

  // We accept only stored Blood Pressure records with a timestamp (as suggested
  // by BLE Blood Pressure Service specification v1.1.1).
  guard isTimestampPresent, data.count >= expectedPayloadSize else { return nil }

  let units = (bytes[0] & 1) != 0 ? "kPa" : "mmHg"

  // Little-endian
  let systolicBytes = UInt16(bytes[2]) << 8 | UInt16(bytes[1])
  let diastolicBytes = UInt16(bytes[4]) << 8 | UInt16(bytes[3])

  // bytes[6] bytes[5]: mean arterial pressure

  let year: UInt16 = UInt16(bytes[8]) << 8 | UInt16(bytes[7])
  let month = bytes[9]
  let day = bytes[10]
  let hour = bytes[11]
  let minute = bytes[12]
  let second = bytes[13]
  
  let components = DateComponents(year: Int(year), month: Int(month), day: Int(day), hour: Int(hour), minute: Int(minute), second: Int(second))
  let date = Calendar.current.date(from: components) ?? .init()

  let idPrefix = "\(date.timeIntervalSince1970.rounded())-"
  let pulseSample: QuantitySample?

  if isPulseRatePresent {
    let pulseBytes: UInt16 = UInt16(bytes[15]) << 8 | UInt16(bytes[14])

    pulseSample = QuantitySample(
      id: "\(idPrefix)pulse",
      value: SFloat.read(data: pulseBytes),
      startDate: date,
      endDate: date,
      type: .cuff,
      unit: "bpm"
    )
  } else {
    pulseSample = nil
  }

  let systolicSample = QuantitySample(
    id: "\(idPrefix)systolic",
    value: SFloat.read(data: systolicBytes),
    startDate: date,
    endDate: date,
    type: .cuff,
    unit: units
  )
  let diastolicSample = QuantitySample(
    id: "\(idPrefix)diastolic",
    value: SFloat.read(data: diastolicBytes),
    startDate: date,
    endDate: date,
    type: .cuff,
    unit: units
  )
  
  return BloodPressureSample(
    systolic: systolicSample,
    diastolic: diastolicSample,
    pulse: pulseSample
  )
}
