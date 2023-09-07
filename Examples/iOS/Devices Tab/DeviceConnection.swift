import SwiftUI
import VitalHealthKit
import VitalDevices
import ComposableArchitecture
import NukeUI
import Combine
import VitalCore

enum DeviceConnection {}

enum Reading: Equatable, Hashable, IdentifiableByHashable {
  case bloodPressure(BloodPressureSample)
  case glucose(QuantitySample)
  
  var isBloodPressure: Bool {
    switch self {
      case .bloodPressure:
        return true
      case .glucose:
        return false
    }
  }
  
  var glucose: QuantitySample? {
    switch self {
      case .bloodPressure:
        return nil
      case let .glucose(glucosePoint):
        return glucosePoint
    }
  }
  
  var bloodPressure: BloodPressureSample? {
    switch self {
      case let .bloodPressure(bloodPressurePoint):
        return bloodPressurePoint
      case .glucose:
        return nil
    }
  }
  
  var date: Date {
    switch self {
      case let .glucose(glucose):
        return glucose.startDate
      case let .bloodPressure(bloodPressure):
        return bloodPressure.systolic.startDate
    }
  }
}

extension DeviceConnection {
  public struct State: Equatable {
    enum Status: String {
      case notSetup = "Missing credentials. Visit settings tab."
      case found = "Found device"
      case pairing = "Pairing with device..."
      case paired = "Device paired"
      case creatingConnectedSource = "Creating a Connected Source via API..."
      case searching = "Searching..."
      case pairingFailed = "Pairing failed"
      case reading = "Reading data..."
      case readingFailed = "Reading failed"
      case sendingToServer = "Sending to server..."
      case deviceNoData = "Device reported no data"
      case serverFailed = "Sending to server failed"
      case connectedSourceCreationFailed = "Failed to create Connected Source for the device"
      case noneFound = "None found"
      case serverSuccess = "Value sent to the server"
    }
    
    let device: DeviceModel
    var status: Status
    var hasPairedSuccessfully = false
    var scannedDevice: ScannedDevice?
    var scanSource: ScanSource?

    var readings: [Reading] = []

    var alertText: String? = nil
    
    init(device: DeviceModel) {
      self.device = device
      self.status = .searching
    }
    
    var isLoading: Bool {
      switch self.status {
        case .serverSuccess, .serverFailed, .pairingFailed:
          return false
        default:
          return true
      }
    }

    var canPair: Bool {
      switch self.status {
      case .searching, .pairingFailed, .serverFailed, .serverSuccess, .found:
          return scannedDevice != nil && hasPairedSuccessfully == false
        default:
          return false
      }
    }

    var canRead: Bool {
      switch self.status {
      case .paired, .readingFailed, .serverSuccess, .serverFailed, .deviceNoData:
          return scannedDevice != nil && hasPairedSuccessfully == true
        default:
          return false
      }
    }

    var deviceScanStatus: String? {
      switch scanSource {
      case .paired?:
        return "Previously Paired"
      case .scanned?:
        return "Discovered via BLE Scan"
      case nil:
        return nil
      }
    }
  }

  public enum ScanSource: Int {
    case paired
    case scanned
  }
  
  public enum Action: Equatable {
    case createConnectedSource
    case startScanning
    case scannedDevice(ScannedDevice, ScanSource)

    case startReading(ScannedDevice)
    case newReading([Reading])
    case readingSentToServer(Reading)
    case failedSentToServer(String)

    case connectedSourceCreationFailure(String)
    
    case pairDevice(ScannedDevice)
    case pairedSuccesfully(ScannedDevice)
    case pairingFailed(String)

    case readingFailed(String)

    case dismissErrorAlert
  }
  
  public struct Environment {
    let deviceManager: DevicesManager
    let mainQueue: DispatchQueue
    let timeZone: TimeZone
  }
}

let deviceConnectionReducer = Reducer<DeviceConnection.State, DeviceConnection.Action, DeviceConnection.Environment> { state, action, env in
  struct LongRunningReads: Hashable {}
  struct DeviceScanning: Hashable {}

  switch action {
    case let .readingSentToServer(reading):
      state.status = .serverSuccess
      return .none

    case .createConnectedSource:
      state.status = .creatingConnectedSource
      let brand = state.device.brand

      return Effect<DeviceConnection.Action, Never>.task {
        guard VitalClient.status.contains([.configured, .signedIn]) else {
          return DeviceConnection.Action.connectedSourceCreationFailure("Vital SDK has not been configured.")
        }

        let provider = DevicesManager.provider(for: brand)
        do {
          try await VitalClient.shared.link.createConnectedSource(for: provider)

          // Start scanning immediately if we have created connected source successfully.
          return DeviceConnection.Action.startScanning
        } catch let error {
          return DeviceConnection.Action.connectedSourceCreationFailure("Failed to create connected source: \(error)")
        }
      }

    case .startScanning:
      state.status = .searching

      // Prefer to use any matching paired BLE device.
      let pairedDevices = env.deviceManager.connected(state.device)
      if !pairedDevices.isEmpty {
          return Effect.send(DeviceConnection.Action.scannedDevice(pairedDevices[0], .paired))
      }

      // If no paired device is found, fallback to scanning for one.
      return env.deviceManager.search(for: state.device)
        .first()
        .map { DeviceConnection.Action.scannedDevice($0, .scanned) }
        .receive(on: env.mainQueue)
        .eraseToEffect()
        .cancellable(id: DeviceScanning())
      
    case let .scannedDevice(device, source):
      state.status = .found
      state.scannedDevice = device
      state.scanSource = source

      return .none
      
    case let .newReading(dataPoints):
      state.status = .sendingToServer
      
      let allReadings = Set(state.readings + dataPoints)
      let unique = Array(allReadings).sorted { $0.date > $1.date }
      
      state.readings = unique
      
      guard let scannedDevice = state.scannedDevice else {
        state.status = .noneFound
        return .none
      }
      
      guard let dataPoint = dataPoints.first else {
        state.status = .deviceNoData
        return .none
      }
      
      if case let .bloodPressure(reading) = dataPoint {
        
        let bloodPressures = dataPoints.compactMap { $0.bloodPressure }
        
        let effect = Effect<Void, Error>.task {
          try await VitalClient.shared.timeSeries.post(
            .bloodPressure(bloodPressures),
            stage: .daily,
            provider: DevicesManager.provider(for: scannedDevice.deviceModel.brand),
            timeZone: env.timeZone
          )
        }
          .map { _ in DeviceConnection.Action.readingSentToServer(dataPoint) }
          .catch { error in
            return Just(DeviceConnection.Action.failedSentToServer(error.localizedDescription))
          }
        
        return effect.receive(on: env.mainQueue).eraseToEffect()
      }
      
      if case let .glucose(reading) = dataPoint {
        
        let glucosePoints = dataPoints.compactMap { $0.glucose }
        
        let effect = Effect<Void, Error>.task {
          try await VitalClient.shared.timeSeries.post(
            .glucose(glucosePoints),
            stage: .daily,
            provider: DevicesManager.provider(for: scannedDevice.deviceModel.brand),
            timeZone: env.timeZone
          )}
          .map { _ in DeviceConnection.Action.readingSentToServer(dataPoint) }
          .catch { error in
            return Just(DeviceConnection.Action.failedSentToServer(error.localizedDescription))
          }
        
        return effect.receive(on: env.mainQueue).eraseToEffect()
      }
      
      return .none
      
    case let .failedSentToServer(reason):
      state.status = .serverFailed
      state.alertText = reason
      return .init(value: .startScanning)

    case let .connectedSourceCreationFailure(reason):
      state.status = .connectedSourceCreationFailed
      state.alertText = reason
      return .none

    case let .startReading(scannedDevice):
      state.status = .reading

      let publisher: AnyPublisher<[Reading], Error>

      if scannedDevice.deviceModel.kind == .bloodPressure {
        let reader = env.deviceManager.bloodPressureReader(for: scannedDevice, queue: env.mainQueue)

        publisher = reader.read(device: scannedDevice)
          .map { $0.map(Reading.bloodPressure) }
          .eraseToAnyPublisher()

      } else {
        let reader = env.deviceManager.glucoseMeter(for: scannedDevice, queue: env.mainQueue)

        publisher = reader.read(device: scannedDevice)
          .map { $0.map(Reading.glucose) }
          .eraseToAnyPublisher()
      }

      return publisher
        .map(DeviceConnection.Action.newReading)
        .catch { error in Just(DeviceConnection.Action.readingFailed(error.localizedDescription))}
        .receive(on: env.mainQueue)
        .eraseToEffect()
        .cancellable(id: LongRunningReads())

      
    case let .readingFailed(reason):
      state.status = .readingFailed
      state.alertText = reason
      return .none
      
    case let .pairingFailed(reason):
      state.status = .pairingFailed
      state.alertText = reason
      return .none
      
    case let .pairedSuccesfully(scannedDevice):
      state.status = .paired
      state.scannedDevice = scannedDevice
      state.hasPairedSuccessfully = true
      return .none
      
    case let .pairDevice(device):
      state.status = .pairing

      let reader: DevicePairable
      
      if device.deviceModel.kind == .bloodPressure {
        reader = env.deviceManager.bloodPressureReader(for: device, queue: env.mainQueue)
      } else {
        reader = env.deviceManager.glucoseMeter(for: device, queue: env.mainQueue)
      }

      return Effect.concatenate(
        Effect.cancel(ids: [LongRunningReads(), DeviceScanning()]),
        reader.pair(device: device)
          .map { _ in DeviceConnection.Action.pairedSuccesfully(device) }
          .catch { error in Just(DeviceConnection.Action.pairingFailed(error.localizedDescription))}
          .receive(on: env.mainQueue)
          .eraseToEffect()
      )


    case .dismissErrorAlert:
      state.alertText = nil
      return .none
  }
}

extension DeviceConnection {
  struct RootView: View {
    
    let store: Store<State, Action>
    
    var body: some View {
      WithViewStore(self.store) { viewStore in
        VStack {
          VStack(alignment: .center, spacing: 5) {
            LazyImage(source: url(for: viewStore.device), resizingMode: .aspectFit)
              .frame(width: 200, height: 200, alignment: .leading)

            Text("\(viewStore.status.rawValue)")
              .font(.system(size: 14))
              .fontWeight(.medium)
              .padding(.all, 5)
              .background(Color(UIColor(red: 198/255, green: 246/255, blue: 213/255, alpha: 1.0)))
              .cornerRadius(5.0)

            if let deviceScanStatus = viewStore.deviceScanStatus {
              Text(deviceScanStatus)
                .font(.system(size: 14))
                .fontWeight(.medium)
                .padding(.all, 5)
                .background(Color(UIColor(red: 198/255, green: 246/255, blue: 213/255, alpha: 1.0)))
                .cornerRadius(5.0)
            }

            HStack {
              Button {
                if let device = viewStore.scannedDevice {
                  viewStore.send(.pairDevice(device))
                }
              } label: {
                Text(viewStore.hasPairedSuccessfully ? "Paired" : "Pair")
              }
              .disabled(viewStore.canPair == false)
              .cornerRadius(8.0)

              Button {
                if let device = viewStore.scannedDevice {
                  viewStore.send(.startReading(device))
                }
              } label: {
                Text("Read")
              }
              .disabled(viewStore.canRead == false)
              .cornerRadius(8.0)
            }
            .buttonStyle(RegularButtonStyle())
            .padding(.vertical, 8)
            .padding(.horizontal, 32)

            Spacer(minLength: 15)
            
            List {
              ForEach(viewStore.readings) { (reading: Reading) in
                
                switch reading {
                  case let .bloodPressure(point):
                    HStack {
                      VStack(alignment: .leading, spacing: 5) {
                        HStack {
                          Text("\(Int(point.systolic.value))")
                            .font(.title)
                            .fontWeight(.medium)
                          Text("\(point.systolic.unit)")
                            .foregroundColor(.gray)
                            .font(.footnote)
                        }
                        
                        HStack {
                          Text("\(Int(point.diastolic.value))")
                            .font(.title)
                            .fontWeight(.medium)
                          Text("\(point.diastolic.unit)")
                            .foregroundColor(.gray)
                            .font(.footnote)
                        }
                        
                        HStack {
                          Text("\(Int(point.pulse?.value ?? 0))")
                            .font(.title)
                            .fontWeight(.medium)
                          Text("bpm")
                            .foregroundColor(.gray)
                            .font(.footnote)
                        }
                      }
                      
                      Spacer()
                      
                      VStack(alignment: .trailing) {
                        Text("\(point.systolic.startDate.getDay())")
                          .font(.body)
                        Text("\(point.systolic.startDate.getDate())")
                          .font(.body)
                      }
                    }
                    .padding([.horizontal], 10)
                  case let .glucose(point):
                    HStack {
                      VStack {
                        Text("\(Int(point.value))")
                          .font(.title)
                          .fontWeight(.medium)
                        
                        Text("\(point.unit)")
                          .font(.footnote)
                      }
                      
                      Spacer()
                      
                      VStack(alignment: .trailing) {
                        Text("\(point.startDate.getDay())")
                          .font(.body)
                        Text("\(point.startDate.getDate())")
                          .font(.body)
                      }
                    }
                    .padding([.horizontal], 10)
                }
              }
            }
          }
        }
        .onAppear {
          viewStore.send(.createConnectedSource)
        }
        .alert(
            store.scope { state -> AlertState<DeviceConnection.Action>? in
              guard let alertText = state.alertText else { return nil }
              return AlertState {
                TextState("Error")
              } actions: {
                ButtonState(role: .none, action: .dismissErrorAlert) {
                  TextState("OK")
                }
              } message: {
                TextState(alertText)
              }
            } action: { $0 },
            dismiss: .dismissErrorAlert
        )
        .environment(\.defaultMinListRowHeight, 25)
        .listStyle(PlainListStyle())
        .background(Color.white)
        .navigationBarTitle(viewStore.device.name, displayMode: .inline)
      }
    }
  }
}
