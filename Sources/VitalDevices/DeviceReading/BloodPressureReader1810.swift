import VitalCore
import CombineCoreBluetooth

public protocol BloodPressureReadable: DevicePairable {
  func read(device: ScannedDevice) -> AnyPublisher<[BloodPressureSample], Error>
}

class BloodPressureReader1810: GATTMeter<BloodPressureSample>, BloodPressureReadable {
  init(
    manager: CentralManager = .live(),
    queue: DispatchQueue
  ) {
    super.init(
      manager: manager,
      queue: queue,
      serviceID: CBUUID(string: "1810".fullUUID),
      measurementCharacteristicID: CBUUID(string: "2A35".fullUUID),
      parser: toBloodPressureReading(data:)
    )
  }
}

private func toBloodPressureReading(data: Data) -> BloodPressureSample? {
  guard data.count >= 16 else { return nil }

  let byteArrayFromData: [UInt8] = [UInt8](data)
  let isTimestampPresent = (byteArrayFromData[0] & 0x02) != 0

  // We accept only stored Blood Pressure records with a timestamp (as suggested
  // by BLE Blood Pressure Service specification v1.1.1).
  guard isTimestampPresent else { return nil }

  let units = (byteArrayFromData[0] & 1) != 0 ? "kPa" : "mmHg"
  
  let systolic: UInt16 = [byteArrayFromData[1], byteArrayFromData[2]].withUnsafeBytes { $0.load(as: UInt16.self) }
  let diastolic: UInt16 = [byteArrayFromData[3], byteArrayFromData[4]].withUnsafeBytes { $0.load(as: UInt16.self) }

  let year: UInt16 = [byteArrayFromData[7], byteArrayFromData[8]].withUnsafeBytes { $0.load(as: UInt16.self) }
  let month = byteArrayFromData[9]
  let day = byteArrayFromData[10]
  let hour = byteArrayFromData[11]
  let minute = byteArrayFromData[12]
  let second = byteArrayFromData[13]
  
  let components = DateComponents(year: Int(year), month: Int(month), day: Int(day), hour: Int(hour), minute: Int(minute), second: Int(second))
  let date = Calendar.current.date(from: components) ?? .init()
  
  let pulseRate: UInt16 = [byteArrayFromData[14], byteArrayFromData[15]].withUnsafeBytes { $0.load(as: UInt16.self) }

  let idPrefix = "\(date.timeIntervalSince1970.rounded())-"
  let systolicSample = QuantitySample(id: "\(idPrefix)systolic", value: Double(systolic), startDate: date, endDate: date, type: "cuff", unit: units)
  let diastolicSample = QuantitySample(id: "\(idPrefix)diastolic", value: Double(diastolic), startDate: date, endDate: date, type: "cuff", unit: units)
  let pulseSample = QuantitySample(id: "\(idPrefix)pulse", value: Double(pulseRate), startDate: date, endDate: date, type: "cuff", unit: "bpm")
  
  return BloodPressureSample(
    systolic: systolicSample,
    diastolic: diastolicSample,
    pulse: pulseSample
  )
}
