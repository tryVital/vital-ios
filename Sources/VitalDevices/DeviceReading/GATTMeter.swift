import VitalCore
import CombineCoreBluetooth
import Combine

internal class GATTMeter<Sample> {
  // 2A52 is the assigned number for Record Access Control Point in GATT.
  private let racpCharacteristicID = CBUUID(string: "2A52".fullUUID)

  private let serviceID: CBUUID
  private let measurementCharacteristicID: CBUUID

  private let manager: CentralManager
  private let queue: DispatchQueue

  private let parser: (Data) -> Sample?
  private let didReceiveAll: (ScannedDevice, [Sample]) -> Void

  init(
    manager: CentralManager,
    queue: DispatchQueue,
    serviceID: CBUUID,
    measurementCharacteristicID: CBUUID,
    parser: @escaping (Data) -> Sample?,
    didReceiveAll: @escaping (ScannedDevice, [Sample]) -> Void
  ) {
    self.manager = manager
    self.queue = DispatchQueue(label: "io.tryvital.VitalDevices.\(Self.self)", target: queue)
    self.serviceID = serviceID
    self.measurementCharacteristicID = measurementCharacteristicID
    self.parser = parser
    self.didReceiveAll = didReceiveAll
  }

  func read(device: ScannedDevice) -> AnyPublisher<[Sample], Error> {
    return _connect(device: device) { (peripheral, characteristics) -> AnyPublisher<[Sample], Error> in
        guard
          let measurementCharacteristic = characteristics.first(where: { $0.uuid == self.measurementCharacteristicID }),
          let RACPCharacteristic = characteristics.first(where: { $0.uuid == self.racpCharacteristicID })
        else {
          return Fail(outputType: [Sample].self, failure: BluetoothError(message: "Missing required characteristics."))
            .eraseToAnyPublisher()
        }
        var cancellables: Set<AnyCancellable> = []

        let write = peripheral.writeValue(Data([1, 1]), for: RACPCharacteristic, type: .withResponse)

        let racpResponse = CurrentValueSubject<RACPResponse?, Error>(nil)
        let racpSuccessOrFailure = racpResponse.compactMap { $0 }.first().tryMap { response in
          switch response {
          case .success, .noRecordsFound:
            return ()
          case .notCompleted, .unknown, .invalidPayloadStructure:
            throw BluetoothRACPError(code: response.code)
          }
        }

        // (1) We first start listening for measurement notifications
        return peripheral
          .listenForUpdates(on: measurementCharacteristic)
          .compactMap { $0.flatMap(self.parser) }
          .prefix(untilOutputFrom: racpSuccessOrFailure)
          .collect()
          .timeout(30.0, scheduler: DispatchQueue.main, customError: { BluetoothError(message: "ReadAllRecords timeout") })
          .handleEvents(
            receiveSubscription: { _ in
              // (2) We then start listening for RACP response indication
              peripheral
                .listenForUpdates(on: RACPCharacteristic)
                .map { $0.map(RACPResponse.init) ?? .invalidPayloadStructure }
                .subscribe(racpResponse)
                .store(in: &cancellables)

              // (3) We finally write to RACP to initiate the Load All Records operation.
              write
                .sink(receiveCompletion: { _ in }, receiveValue: {})
                .store(in: &cancellables)
            },
            receiveOutput: { [call = self.didReceiveAll, device] in call(device, $0) },
            receiveCompletion: { _ in
              cancellables.forEach { $0.cancel() }

              // Disconnect when we have done reading. Some devices rely on BLE disconnection as
              // a cue to toast users with a "Transferred Completed" message.
              self.manager.cancelPeripheralConnection(peripheral)
            },
            receiveCancel: {
              cancellables.forEach { $0.cancel() }
            }
          )
          .eraseToAnyPublisher()
    }
  }

  func pair(device: ScannedDevice) -> AnyPublisher<Void, Error> {
    _connect(device: device, then: { _, _ in Just(()).setFailureType(to: Error.self) })
  }

  private func _connect<P>(
    device: ScannedDevice,
    then action: @escaping (Peripheral, [CBCharacteristic]) -> P
  ) -> AnyPublisher<P.Output, Error> where P: Publisher, P.Failure == Error {
    let isOn = manager
      .didUpdateState
      .prepend(manager.state)
      .filter { $0 == .poweredOn }
      .first()
      .mapError { _ -> Error in }

    return isOn
      .flatMapLatest { _ in self._connectAndDiscoverCharacteristics(for: device, then: action) }
  }

  private func _connectAndDiscoverCharacteristics<P>(
    for device: ScannedDevice,
    then action: @escaping (Peripheral, [CBCharacteristic]) -> P
  ) -> AnyPublisher<P.Output, Error> where P: Publisher, P.Failure == Error {
    return manager.connect(device.peripheral).flatMapLatest { peripheral -> AnyPublisher<P.Output, Error> in
      peripheral.discoverServices([self.serviceID])
        .flatMapLatest { services -> AnyPublisher<[CBCharacteristic], Error> in
          guard services.isEmpty == false else {
            return .empty
          }

          return peripheral.discoverCharacteristics([self.measurementCharacteristicID, self.racpCharacteristicID], for: services[0])
        }
        .flatMapLatest { characteristics -> AnyPublisher<(Peripheral, [CBCharacteristic]), Error> in
          guard characteristics.count == 2 else {
            return .empty
          }
          let second = peripheral.setNotifyValue(true, for: characteristics[1])
          let first = peripheral.setNotifyValue(true, for: characteristics[0])

          let zipped = first.zip(second).first().eraseToAnyPublisher()

          return zipped.map { _ in
            return (peripheral, characteristics)
          }
          .eraseToAnyPublisher()
        }
        // Take the first valid set of characteristics emitted, and stop the service discovery.
        //
        // This cannot be placed on the outer `.connect()` chain.
        // `first()` cancels its upstream subscription, which means it will cancel `connect()`.
        // `connect()` cancels the CBPeripheral connection when it catches a cancellation.
        .first()
        .flatMapLatest { action($0.0, $0.1) }
    }
    .eraseToAnyPublisher()
  }
}

