import SwiftUI
import VitalHealthKit
import VitalDevices
import ComposableArchitecture
import NukeUI
import Combine

enum DeviceConnection {}

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
    
    var readings: [BloodPressureDataPoint] = []
    
    init(device: DeviceModel) {
      self.device = device
      self.status = .searching
    }
  }
  
  public enum Action: Equatable {
    case startScanning
    case scannedDevice(ScannedDevice)
    
    case newDataPoint(BloodPressureDataPoint)
    
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
  
  switch action {
    case .startScanning:
      return env.deviceManager.startSearch(for: state.device)
        .first()
        .map(DeviceConnection.Action.scannedDevice)
        .receive(on: env.mainQueue)
        .eraseToEffect()
      
    case let .scannedDevice(device):
      state.status = .found
      state.scannedDevice = device
      
      return Effect<DeviceConnection.Action, Never>(value: DeviceConnection.Action.pairDevice(device))
      
    case let .newDataPoint(dataPoint):
      
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
      let reader = env.deviceManager.bloodPressureReader(for: scannedDevice)
      
      return reader.read(device: scannedDevice)
        .map(DeviceConnection.Action.newDataPoint)
        .catch { error in Just(DeviceConnection.Action.readingFailed(error.localizedDescription))}
        .receive(on: env.mainQueue)
        .eraseToEffect()
        .cancellable(id: LongRunningReads())

      
    case let .pairDevice(device):
      let reader = env.deviceManager.bloodPressureReader(for: device)
      
      return reader.pair(device: device)
        .map { _ in DeviceConnection.Action.pairedSuccesfully(device) }
        .catch { error in Just(DeviceConnection.Action.pairingFailed(error.localizedDescription))}
        .receive(on: env.mainQueue)
        .eraseToEffect()
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
              ForEach(viewStore.readings) { point in
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
