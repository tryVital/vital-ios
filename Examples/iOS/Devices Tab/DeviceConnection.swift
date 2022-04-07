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
}

extension DeviceConnection {
  public struct State: Equatable {
    enum Status: String {
      case found = "Found device"
      case paired = "Device paired"
      case searching = "Searching"
      case pairingFailed = "Pairing failed"
      case readingFailed = "Reading failed"
      case serverFailed = "Sending to server failed"
      case noneFound = "None found"
      case serverSuccess = "Value sent to the server"
    }
    
    let device: DeviceModel
    var status: Status
    var scannedDevice: ScannedDevice?
    
    var readings: [Reading] = []
    
    init(device: DeviceModel) {
      self.device = device
      self.status = .searching
    }
  }
  
  public enum Action: Equatable {
    case startScanning
    case scannedDevice(ScannedDevice)
    
    case scannedDeviceUpdate(Bool)
    
    case newReading([Reading])
    case readingSentToServer(Reading)
    case failedSentToServer(String)
    
    case pairDevice(ScannedDevice)
    case pairedSuccesfully(ScannedDevice)
    case pairingFailed(String)
    
    case readingFailed(String)
  }
  
  public struct Environment {
    let deviceManager: DevicesManager
    let mainQueue: AnySchedulerOf<DispatchQueue>
  }
}

let deviceConnectionReducer = Reducer<DeviceConnection.State, DeviceConnection.Action, DeviceConnection.Environment> { state, action, env in
  struct LongRunningReads: Hashable {}
  struct LongRunningScan: Hashable {}
  
  switch action {
    case let .readingSentToServer(reading):
      state.status = .serverSuccess
      return .none
      
    case .startScanning:
      return env.deviceManager.search(for: state.device)
        .first()
        .map(DeviceConnection.Action.scannedDevice)
        .receive(on: env.mainQueue)
        .eraseToEffect()

    case let .scannedDevice(device):
      state.status = .found
      state.scannedDevice = device
      
      let pairedSuccessfully = Effect<DeviceConnection.Action, Never>(value: DeviceConnection.Action.pairedSuccesfully(device))
      
      let monitorDevice = env.deviceManager.monitorConnection(for: device).map(DeviceConnection.Action.scannedDeviceUpdate)
        .receive(on: env.mainQueue)
        .eraseToEffect()
        .cancellable(id: LongRunningScan())
      
      return Effect.concatenate(pairedSuccessfully, monitorDevice)
      
    case let .newReading(dataPoints):
      state.readings.append(contentsOf: dataPoints)
      
      guard let scannedDevice = state.scannedDevice else {
        return .none
      }
      
      guard let dataPoint = dataPoints.first else {
        return .none
      }
      
      if case let .bloodPressure(reading) = dataPoint {
        
        let bloodPressures = dataPoints.compactMap { $0.bloodPressure }
        
        let effect = Effect<Void, Error>.task {
          try await VitalNetworkClient.shared.summary.post(
            resource: .bloodPressure(bloodPressures, .daily, .omron)
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
          
          try await VitalNetworkClient.shared.summary.post(
            resource: .glucose(glucosePoints, .daily, .accucheck)
          )
        }
          .map { _ in DeviceConnection.Action.readingSentToServer(dataPoint) }
          .catch { error in
            return Just(DeviceConnection.Action.failedSentToServer(error.localizedDescription))
          }
        
        return effect.receive(on: env.mainQueue).eraseToEffect()
      }
      

      return .none
      
    case let .failedSentToServer(reason):
      state.status = .serverFailed
      return .none
      
    case let .readingFailed(reason):
      state.status = .readingFailed
      return .none
      
    case let .pairingFailed(reason):
      state.status = .pairingFailed
      return .none
      
    case let .pairedSuccesfully(scannedDevice):
      state.status = .paired
      state.scannedDevice = scannedDevice
      
      let publisher: AnyPublisher<Reading, Error>
      
      if scannedDevice.kind == .bloodPressure {
        let reader = env.deviceManager.bloodPressureReader(for: scannedDevice)
        
        publisher = reader.read(device: scannedDevice)
          .map(Reading.bloodPressure)
          .eraseToAnyPublisher()
        
      } else {
        let reader = env.deviceManager.glucoseMeter(for: scannedDevice)
        
        publisher = reader.read(device: scannedDevice)
          .map(Reading.glucose)
          .eraseToAnyPublisher()
      }
      
      return publisher
        .collect(.byTimeOrCount(env.mainQueue, 5.0, 50))
        .map(DeviceConnection.Action.newReading)
        .catch { error in Just(DeviceConnection.Action.readingFailed(error.localizedDescription))}
        .receive(on: env.mainQueue)
        .eraseToEffect()
        .cancellable(id: LongRunningReads())
      
      
    case let .pairDevice(device):
      let reader: DevicePairable
      
      if device.kind == .bloodPressure {
        reader = env.deviceManager.bloodPressureReader(for: device)
      } else {
        reader = env.deviceManager.glucoseMeter(for: device)
      }
      
      return reader.pair(device: device)
        .map { _ in DeviceConnection.Action.pairedSuccesfully(device) }
        .catch { error in Just(DeviceConnection.Action.pairingFailed(error.localizedDescription))}
        .receive(on: env.mainQueue)
        .eraseToEffect()
      
    case let .scannedDeviceUpdate(isConnected):
      print(isConnected)
      return .none
  }
}

extension DeviceConnection {
  struct RootView: View {
    
    let store: Store<State, Action>
    
    var body: some View {
      WithViewStore(self.store) { viewStore in
        VStack {
          VStack(alignment: .center) {
            LazyImage(source: url(for: viewStore.device), resizingMode: .aspectFit)
              .frame(width: 200, height: 200, alignment: .leading)
            Text("Status: \(viewStore.status.rawValue)")
            Spacer()
            
            List {
              ForEach(viewStore.readings) { (reading: Reading) in
                
                switch reading {
                  case let .bloodPressure(point):
                    HStack {
                      VStack {
                        HStack {
                          Text("\(point.systolic.value)")
                          Text("\(point.systolic.unit)")
                        }
                        
                        HStack {
                          Text("\(point.diastolic.value)")
                          Text("\(point.diastolic.unit)")
                        }
                        
                        HStack {
                          Text("\(point.pulse.value)")
                          Text("bpm")
                        }
                      }
                      Text("\(point.systolic.startDate)")
                        .foregroundColor(.gray)
                        .font(.footnote)
                    }
                  case let .glucose(point):
                    HStack {
                      VStack {
                        Text("\(point.value)")
                        Text("\(point.unit ?? "")")
                      }
                      Text("\(point.startDate)")
                        .foregroundColor(.gray)
                        .font(.footnote)
                    }
                }
              }
            }
          }
        }
        .onAppear {
          viewStore.send(.startScanning)
        }
        .environment(\.defaultMinListRowHeight, 25)
        .listStyle(PlainListStyle())
        .background(Color.white)
        .navigationBarTitle(viewStore.device.name, displayMode: .inline)
      }
    }
  }
}
