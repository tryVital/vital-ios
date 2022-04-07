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
}

extension DeviceConnection {
  public struct State: Equatable {
    enum Status: String {
      case found = "Found device"
      case paired = "Device paired"
      case searching = "Searching"
      case pairingFailed = "Pairing failed"
      case readingFailed = "Reading failed"
      case noneFound = "None found"
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
    
    case newReading(Reading)
    
    case pairDevice(ScannedDevice)
    case pairedSuccesfully(ScannedDevice)
    case pairingFailed(String)
    
    case readingFailed(String)
    
    case lol
    case lolFailure(String)
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
    case .lol:
      print("lol")
      return .none
    case let .lolFailure(error):
      print(error)
      return .none
      
    case .startScanning:
      let effect = Effect<Void, Error>.task {
        let patch = GlucosePatch(glucose: [.init(value: 10, startDate: .init(), endDate: .init())])
        
        try await VitalNetworkClient.shared.summary.post(to: .glucose(patch, .historical(start: .init(), end: .init())))
        }
        .map { _ in DeviceConnection.Action.lol}
        .catch { error in
          return Just(DeviceConnection.Action.lolFailure(error.localizedDescription))
          
        }

      return effect.receive(on: env.mainQueue).eraseToEffect()
//      return env.deviceManager.startSearch(for: state.device)
//        .first()
//        .map(DeviceConnection.Action.scannedDevice)
//        .receive(on: env.mainQueue)
//        .eraseToEffect()
      
    case let .scannedDevice(device):
      state.status = .found
      state.scannedDevice = device
      
      let pairedSuccessfully = Effect<DeviceConnection.Action, Never>(value: DeviceConnection.Action.pairedSuccesfully(device))
      
      let monitorDevice = env.deviceManager.monitorConnection(for: device).map(DeviceConnection.Action.scannedDeviceUpdate)
        .receive(on: env.mainQueue)
        .eraseToEffect()
        .cancellable(id: LongRunningScan())
      
      return Effect.concatenate(pairedSuccessfully, monitorDevice)
      
    case let .newReading(dataPoint):
      
      if state.readings.contains(dataPoint) == false {
        state.readings.append(dataPoint)
      }

      return .none
      
    case let .readingFailed(reason):
      state.status = .readingFailed
      return .none
      
    case let .pairingFailed(reason):
      state.status = .pairingFailed
      return .none
      
    case let .pairedSuccesfully(scannedDevice):
      state.status = .paired
      
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
                          Text("\(point.systolic)")
                          Text("\(point.units)")
                        }
                        
                        HStack {
                          Text("\(point.diastolic)")
                          Text("\(point.units)")
                        }
                        
                        HStack {
                          Text("\(point.pulseRate)")
                          Text("bpm")
                        }
                      }
                      Text("\(point.date)")
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
