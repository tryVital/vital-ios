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
      case paired = "Device paired"
      case searching = "Searching..."
      case pairingFailed = "Pairing failed"
      case readingFailed = "Reading failed"
      case sendingToServer = "Sending to server..."
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
    
    var isLoading: Bool {
      switch self.status {
        case .serverSuccess, .serverFailed, .pairingFailed:
          return false
        default:
          return true
      }
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
    let mainQueue: DispatchQueue
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
      let brand = state.device.brand
      state.status = .searching
      
      let createConnectedSource = Effect<Void, Error>.task {
        let provider = DevicesManager.provider(for: brand)
        try await VitalClient.shared.link.createConnectedSource(for: provider)
      }
      
      let search = env.deviceManager.search(for: state.device)
        .first()
        .map(DeviceConnection.Action.scannedDevice)
        .receive(on: env.mainQueue)
        .eraseToEffect()
      
      return Effect.concatenate(createConnectedSource.fireAndForget(), search)
      
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
      state.status = .sendingToServer
      
      let allReadings = Set(state.readings + dataPoints)
      let unique = Array(allReadings).sorted { $0.date > $1.date }
      
      state.readings = unique
      
      guard let scannedDevice = state.scannedDevice else {
        return .none
      }
      
      guard let dataPoint = dataPoints.first else {
        return .none
      }
      
      if case let .bloodPressure(reading) = dataPoint {
        
        let bloodPressures = dataPoints.compactMap { $0.bloodPressure }
        
        let effect = Effect<Void, Error>.task {
          try await VitalClient.shared.timeSeries.post(
            .bloodPressure(bloodPressures),
            stage: .daily,
            provider: DevicesManager.provider(for: scannedDevice.deviceModel.brand)
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
            provider: DevicesManager.provider(for: scannedDevice.deviceModel.brand)
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
      return .init(value: .startScanning)
      
    case let .readingFailed(reason):
      state.status = .readingFailed
      return .none
      
    case let .pairingFailed(reason):
      state.status = .pairingFailed
      return .none
      
    case let .pairedSuccesfully(scannedDevice):
      state.status = .paired
      state.scannedDevice = scannedDevice
      
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
      
      
    case let .pairDevice(device):
      let reader: DevicePairable
      
      if device.deviceModel.kind == .bloodPressure {
        reader = env.deviceManager.bloodPressureReader(for: device, queue: env.mainQueue)
      } else {
        reader = env.deviceManager.glucoseMeter(for: device, queue: env.mainQueue)
      }
      
      return reader.pair(device: device)
        .map { _ in DeviceConnection.Action.pairedSuccesfully(device) }
        .catch { error in Just(DeviceConnection.Action.pairingFailed(error.localizedDescription))}
        .receive(on: env.mainQueue)
        .eraseToEffect()
      
    case let .scannedDeviceUpdate(isConnected):
      if isConnected == false {
        return .init(value: .startScanning)
      } else {
        return .none
      }
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
