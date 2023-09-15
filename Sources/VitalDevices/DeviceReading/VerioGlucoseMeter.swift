import VitalCore
import CombineCoreBluetooth
import Combine


internal class VerioGlucoseMeter: GlucoseMeterReadable {
  static let serviceID = CBUUID(string: "af9df7a1-e595-11e3-96b4-0002a5d5c51b")
  private static let commandCharacteristicID = CBUUID(string: "af9df7a2-e595-11e3-96b4-0002a5d5c51b")
  private static let notificationCharactersiticID = CBUUID(string: "af9df7a3-e595-11e3-96b4-0002a5d5c51b")

  private let manager: CentralManager
  private let queue: DispatchQueue

  init(
    manager: CentralManager,
    queue: DispatchQueue,
    listenTimeout: TimeInterval = 30.0
  ) {
    self.manager = manager
    self.queue = DispatchQueue(label: "io.tryvital.VitalDevices.\(Self.self)", target: queue)
  }

  func read(device: ScannedDevice) -> AnyPublisher<[QuantitySample], Error> {
    return _connect(device: device) { (peripheral, command, notification) -> AnyPublisher<[QuantitySample], Error> in
        var cancellables: Set<AnyCancellable> = []

        // (1) We first start listening for measurement notifications
        return peripheral
          .listenForUpdates(on: notification)
          .compactMap { $0.flatMap(parser) }
          .collect()
          .handleEvents(
            receiveSubscription: { _ in
              // (2) We enable notificiation again to signal the RACP-less device to start
              // sending values
              peripheral.setNotifyValue(true, for: notification)
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
    _connect(device: device) { (peripheral, command, notification) in
      return Just(()).setFailureType(to: Error.self)
    }
    .eraseToAnyPublisher()
  }

  private func _connect<P>(
    device: ScannedDevice,
    then action: @escaping (Peripheral, _ command: CBCharacteristic, _ notification: CBCharacteristic) -> P
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
    then action: @escaping (Peripheral, _ command: CBCharacteristic, _ notification: CBCharacteristic) -> P
  ) -> AnyPublisher<P.Output, Error> where P: Publisher, P.Failure == Error {
    return manager.connect(device.peripheral).flatMapLatest { peripheral -> AnyPublisher<P.Output, Error> in
      peripheral.discoverServices([Self.serviceID])
        .flatMapLatest { services -> AnyPublisher<[CBCharacteristic], Error> in
          guard services.isEmpty == false else {
            return .empty
          }

          return peripheral.discoverCharacteristics([Self.commandCharacteristicID, Self.notificationCharactersiticID], for: services[0])
        }
        .compactMap { characteristics -> (Peripheral, CBCharacteristic, CBCharacteristic)? in
          guard
            let commandCharacteristic = characteristics.first(where: { $0.uuid == Self.commandCharacteristicID }),
            let notificationCharacteristic = characteristics.first(where: { $0.uuid == Self.notificationCharactersiticID })
          else {
            return nil
          }

          return (peripheral, commandCharacteristic, notificationCharacteristic)
        }
        // Take the first valid set of characteristics emitted, and stop the service discovery.
        //
        // This cannot be placed on the outer `.connect()` chain.
        // `first()` cancels its upstream subscription, which means it will cancel `connect()`.
        // `connect()` cancels the CBPeripheral connection when it catches a cancellation.
        .first()
        .flatMapLatest { peripheral, command, notification in
          Publishers.Concatenate(
            // Make sure that we are ready to receive notification
            prefix: peripheral.setNotifyValue(true, for: notification).ignoreOutput().map { _ -> P.Output in },
            suffix: action(peripheral, command, notification)
          )
        }
        .eraseToAnyPublisher()
    }
    .eraseToAnyPublisher()
  }
}

private func parser(_ data: Data) -> QuantitySample? {
  return nil
}
