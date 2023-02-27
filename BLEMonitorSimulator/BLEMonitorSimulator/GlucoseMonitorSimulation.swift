import CoreBluetooth
import Combine

final class GlucoseMonitorSimulation: NSObject, ObservableObject {
  static let localName = "meter"
  static let notifyRetry: Duration = .milliseconds(16)

  struct TimelineEntry: Hashable, Identifiable {
    let date: Date
    let text: String

    var id: Date { date }
  }

  enum ManagerState: String {
    case unknown
    case resetting
    case unsupported
    case unauthorized
    case poweredOff
    case poweredOn

    init(_ state: CBManagerState) {
      switch state {
      case .unknown:
        self = .unknown
      case .poweredOff:
        self = .poweredOff
      case .poweredOn:
        self = .poweredOn
      case .resetting:
        self = .resetting
      case .unauthorized:
        self = .unauthorized
      case .unsupported:
        self = .unsupported
      @unknown default:
        self = .unknown
      }
    }
  }

  @Published var state: ManagerState = .unknown
  @Published var isAdvertising: Bool = false
  @Published var timeline: [TimelineEntry] = []
  @Published var subscribers: [UUID] = []

  private var manager: CBPeripheralManager!
  private var service: CBMutableService!
  private var measurement: CBMutableCharacteristic!
  private var accessControl: CBMutableCharacteristic!

  private var bag: Set<AnyCancellable> = []

  override init() {
    super.init()
    manager = CBPeripheralManager(
      delegate: self,
      queue: .main
    )

    // service 1808
    service = CBMutableService(type: CBUUID(string: "00001808-0000-1000-8000-00805f9b34fb"), primary: true)
    
    measurement = CBMutableCharacteristic(
      type: .glucoseMeasurement,
      properties: [.notify],
      value: nil,
      permissions: .readable
    )
    accessControl = CBMutableCharacteristic(
      type: .recordAccessControlPoint,
      properties: [.indicate, .write],
      value: nil,
      permissions: .writeEncryptionRequired
    )

    service.characteristics = [measurement, accessControl]
  }

  func start() {
    $state.filter { $0 == .poweredOn }.first()
      .sink { [weak self] _ in
        guard let self = self else { return }

        self.manager.add(self.service)

        self.manager.startAdvertising([
          CBAdvertisementDataLocalNameKey: Self.localName,
          CBAdvertisementDataServiceUUIDsKey: [self.service.uuid]
        ])
      }
      .store(in: &bag)
  }

  @MainActor
  private func notifyStubValues(sequenceNumber: Int) async throws {
    guard subscribers.count > 0 else {
      self.timeline.append(TimelineEntry(date: Date.now, text: "No subscriber is present for measurement \(sequenceNumber). Aborted."))
      throw CancellationError()
    }

    // Typical blood sugar level: 90-100 mg/dL
    let valueInMgDL = Double((900 ... 1000).randomElement()!) / 10
    // Convert it to kg/L as per BLE Glucose Service spec
    let value = valueInMgDL / 100000

    var data = Data()

    // flag: 1 byte
    // 0001b / 0x01: time offset present (in minutes)
    // 0010b / 0x02: glucose data present
    data.append(contentsOf: [0x03])

    // sequence number: 2 bytes
    data.append(contentsOf: UInt16(sequenceNumber).data(bytes: 2))

    // basetime: 7 bytes
    // - year: 2 bytes
    // - month: 1 byte
    // - day: 1 byte
    // - hour: 1 byte
    // - minute: 1 byte
    // - second: 1 byte
    let calendar = Calendar(identifier: .gregorian)
    let component = calendar.dateComponents([.year, .month, .day], from: calendar.date(byAdding: .day, value: sequenceNumber, to: .now)!)
    data.append(contentsOf: UInt16(component.year!).data(bytes: 2))
    data.append(contentsOf: [UInt8(component.month!), UInt8(component.day!), 12, 34, 56])

    // timeoffset: 2 bytes uint16, in minutes
    data.append(contentsOf: UInt16(60).data(bytes: 2))

    // glucose: 3 bytes
    // - concentration: sfloat 2 bytes
    // - typeAndSampleLocation: 1 bytes
    data.append(contentsOf: SFloat.write(value: value).data(bytes: 2))
    data.append(contentsOf: [0x00])

    guard self.manager.updateValue(data, for: self.measurement, onSubscribedCentrals: nil) else {
      self.timeline.append(TimelineEntry(date: Date.now, text: "Failed to notify measurement \(sequenceNumber). Retrying..."))

      try await Task.sleep(for: Self.notifyRetry)
      try await notifyStubValues(sequenceNumber: sequenceNumber)

      return
    }

    self.timeline.append(TimelineEntry(date: Date.now, text: "Notified measurement \(sequenceNumber) with value \(value)."))
  }
}

extension GlucoseMonitorSimulation: CBPeripheralManagerDelegate {
  func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
    self.state = ManagerState(peripheral.state)
    self.timeline.append(TimelineEntry(date: Date.now, text: "managed state changed to: \(self.state)"))
  }

  func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
    self.isAdvertising = error == nil

    if let error = error {
      timeline.append(TimelineEntry(date: Date.now, text: "advertising failed to start: " + error.localizedDescription))
    } else {
      timeline.append(TimelineEntry(date: Date.now, text: "started advertising"))
    }
  }

  func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic) {
    timeline.append(TimelineEntry(date: Date.now, text: "subscriber connected: \(central.identifier)"))

    if !subscribers.contains(central.identifier) {
      subscribers.append(central.identifier)
    }
  }

  func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didUnsubscribeFrom characteristic: CBCharacteristic) {
    timeline.append(TimelineEntry(date: Date.now, text: "subscriber disconnected: \(central.identifier)"))

    if let index = subscribers.firstIndex(of: central.identifier) {
      subscribers.remove(at: index)
    }
  }

  func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
    for request in requests {
      timeline.append(TimelineEntry(date: Date.now, text: "processing write request on characteristic \(request.characteristic.friendlyName) from subscriber \(request.central.identifier)"))

      if request.characteristic.uuid == accessControl.uuid {
        let data = request.value ?? Data()

        // [requestcode, operator]
        if data == Data([1, 1]) {
          // Respond only to Read Histroical Records + All Records
          peripheral.respond(to: request, withResult: .success)

          Task { @MainActor in
            do {
              for index in 0 ..< 20 {
                try await notifyStubValues(sequenceNumber: index)
              }

              // [opcode, operator, requestcode, respcode]
              try await sendRACPResponse(data: Data([6, 0, 1, 1]), for: accessControl, to: request.central, using: peripheral)
            } catch _ {
              // [opcode, operator, requestcode, respcode]
              try await sendRACPResponse(data: Data([6, 0, 1, 8]), for: accessControl, to: request.central, using: peripheral)
            }
          }
        } else {
          peripheral.respond(to: request, withResult: .requestNotSupported)
        }
      }
    }
  }

  @MainActor
  func sendRACPResponse(data: Data, for characteristics: CBMutableCharacteristic, to central: CBCentral, using manager: CBPeripheralManager) async throws {
    let success = manager.updateValue(data, for: characteristics, onSubscribedCentrals: [central])

    guard success else {
      self.timeline.append(TimelineEntry(date: Date.now, text: "Failed to indicate \(characteristics.friendlyName) (data = \(data.hexString)) to \(central.identifier). Retrying..."))
      try await Task.sleep(for: Self.notifyRetry)
      try await sendRACPResponse(data: data, for: characteristics, to: central, using: manager)
      return
    }

    self.timeline.append(TimelineEntry(date: Date.now, text: "Successfully indicated \(characteristics.friendlyName) (data = \(data.hexString)) to \(central.identifier)."))
  }
}

extension CBUUID {
  static var glucoseMeasurement: CBUUID {
    CBUUID(string: "00002A18-0000-1000-8000-00805f9b34fb")
  }

  static var recordAccessControlPoint: CBUUID {
    CBUUID(string: "00002A52-0000-1000-8000-00805f9b34fb")
  }
}

extension CBCharacteristic {
  var friendlyName: String {
    let uuid = self.uuid

    if uuid == .recordAccessControlPoint {
      return "RACP"
    }

    if uuid == .glucoseMeasurement {
      return "Glucose Meas."
    }

    return uuid.uuidString
  }
}

extension Data {
  var hexString: String {
    map { byte in String(format: "%02X", byte) }.joined(separator: ",")
  }
}
