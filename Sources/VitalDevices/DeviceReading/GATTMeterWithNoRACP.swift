import VitalCore
import CombineCoreBluetooth
import Combine

private enum StreamValue<Sample> {
  case value(Sample)
  case waitForNextValueTimedOut

  var sample: Sample? {
    switch self {
    case let .value(sample):
      return sample
    case .waitForNextValueTimedOut:
      return nil
    }
  }

  var isWaitForNextValueTimeout: Bool {
    switch self {
    case .value:
      return false
    case .waitForNextValueTimedOut:
      return true
    }
  }
}

private struct NextValueTimeout: Error {}

/// GATT Meter base class but for devices not having implemented Record Access Control Point (RACP).
///
/// These devices do not support the Read All Records operation, and do not post any notification upon
/// end of data transfer. So we can only listen for incoming notifications passively, and ends the streaming
/// based on a fixed timeout.
internal class GATTMeterWithNoRACP<Sample> {
  private let serviceID: CBUUID
  private let measurementCharacteristicID: CBUUID

  private let manager: CentralManager
  private let queue: DispatchQueue

  private let parser: (Data) -> Sample?

  /// The timeout used to wait on the next value after having received a previous value.
  /// If another value is delivered before the timeout, the timeout is restarted.
  /// If the timeout is reached w/o any delivery, the reading process ends.
  private let waitForNextValueTimeout: TimeInterval

  /// Overall timeout of the publisher, in case no value is ever delivered.
  private let listenTimeout: TimeInterval

  init(
    manager: CentralManager,
    queue: DispatchQueue,
    serviceID: CBUUID,
    measurementCharacteristicID: CBUUID,
    waitForNextValueTimeout: TimeInterval = 2.0,
    listenTimeout: TimeInterval = 30.0,
    parser: @escaping (Data) -> Sample?
  ) {
    self.manager = manager
    self.queue = DispatchQueue(label: "io.tryvital.VitalDevices.\(Self.self)", target: queue)
    self.serviceID = serviceID
    self.measurementCharacteristicID = measurementCharacteristicID
    self.parser = parser
    self.waitForNextValueTimeout = waitForNextValueTimeout
    self.listenTimeout = listenTimeout
  }

  func read(device: ScannedDevice) -> AnyPublisher<[Sample], Error> {
    return _connect(device: device) { (peripheral, measurementCharacteristic) -> AnyPublisher<[Sample], Error> in
        var cancellables: Set<AnyCancellable> = []

        // (1) We first start listening for measurement notifications
        return peripheral
          .listenForUpdates(on: measurementCharacteristic)
          .compactMap { $0.flatMap(self.parser) }
          .flatMapLatest { sample -> AnyPublisher<StreamValue<Sample>, Error> in
            // Sends the incoming sample immediately via `.prepend(_:)`.
            // Then we start a timeout publisher with `self.waitForNextValueTimeout`.
            // - If the timeout is reached, we emit `StreamValue.waitDidTimeout`.
            // - If the next sample is emitted before the timeout, this publisher would be cancelled
            //   by `flatMapLatest` and therefore is a no-op.
            Empty(completeImmediately: false, outputType: StreamValue<Sample>.self, failureType: Error.self)
              .timeout(.milliseconds(Int(self.waitForNextValueTimeout * 1000)), scheduler: self.queue)
              .replaceEmpty(with: StreamValue.waitForNextValueTimedOut)
              .prepend(StreamValue.value(sample))
              .eraseToAnyPublisher()
          }
          // Collect until either:
          // - the `self.listenTimeout` timeout is reached; or
          // - we receive a `StreamValue.waitDidTimeout`.
          .timeout(.milliseconds(Int(self.listenTimeout * 1000)), scheduler: self.queue)
          .prefix(while: { $0.isWaitForNextValueTimeout == false })
          .collect()
          .map { $0.compactMap { $0.sample } }
          .handleEvents(
            receiveSubscription: { _ in
              // (2) We enable notificiation again to signal the RACP-less device to start
              // sending values
              peripheral.setNotifyValue(true, for: measurementCharacteristic)
                .sink(receiveCompletion: { _ in }, receiveValue: {})
                .store(in: &cancellables)
            },
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
    _connect(device: device) { (peripheral, measurementCharacteristic) in
      // Enable indications on the characteristic to force a pairing session
      peripheral.setNotifyValue(true, for: measurementCharacteristic)
    }
    .eraseToAnyPublisher()
  }

  private func _connect<P>(
    device: ScannedDevice,
    then action: @escaping (Peripheral, CBCharacteristic) -> P
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
    then action: @escaping (Peripheral, CBCharacteristic) -> P
  ) -> AnyPublisher<P.Output, Error> where P: Publisher, P.Failure == Error {
    return manager.connect(device.peripheral).flatMapLatest { peripheral -> AnyPublisher<P.Output, Error> in
      peripheral.discoverServices([self.serviceID])
        .flatMapLatest { services -> AnyPublisher<[CBCharacteristic], Error> in
          guard services.isEmpty == false else {
            return .empty
          }

          return peripheral.discoverCharacteristics([self.measurementCharacteristicID], for: services[0])
        }
        .compactMap { characteristics -> (Peripheral, CBCharacteristic)? in
          guard
            let measurementCharacteristic = characteristics.first(where: { $0.uuid == self.measurementCharacteristicID })
          else {
            return nil
          }

          // Unlike a BLE device with RACP support, we do not want to enable BLE notification here.
          // This is because some RACP-less devices may use the enablement as a signal to
          // start sending records unilaterally, and a lot of them discards the records afterwards.
          // In some cases, they also initiate pairing only when the BLE Central attempts to
          // enable indication on a characteristic.
          //
          // Only enable indications when the SDK user explicitly requests a pairing via `pair()`,
          // or when we start reading the records via `read()`.
          return (peripheral, measurementCharacteristic)
        }
        // Take the first valid set of characteristics emitted, and stop the service discovery.
        //
        // This cannot be placed on the outer `.connect()` chain.
        // `first()` cancels its upstream subscription, which means it will cancel `connect()`.
        // `connect()` cancels the CBPeripheral connection when it catches a cancellation.
        .first()
        .flatMapLatest { action($0.0, $0.1) }
        .eraseToAnyPublisher()
    }
    .eraseToAnyPublisher()
  }
}

