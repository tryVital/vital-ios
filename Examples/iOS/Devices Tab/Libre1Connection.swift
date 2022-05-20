import SwiftUI
import VitalHealthKit
import VitalDevices
import ComposableArchitecture
import NukeUI
import Combine
import VitalCore

extension QuantitySample: IdentifiableByHashable {}

enum Libre1Connection {}

extension Libre1Connection {
  public struct State: Equatable {
    enum Status: String {
      case notSetup = "Missing credentials. Visit settings tab."
      case readingFailed = "Reading failed"
      case sendingToServer = "Sending to server..."
      case serverFailed = "Sending to server failed"
      case noneFound = "None found"
      case ready = "Ready"
      case reading = "Reading"
      case serverSuccess = "Value sent to the server"
    }
    
    let device: DeviceModel
    var status: Status
    var scannedDevice: ScannedDevice?
    
    var read: Libre1Read?
    
    init(device: DeviceModel) {
      self.status = .ready
      self.device = device
    }
    
    var isLoading: Bool {
      switch self.status {
        case .reading, .sendingToServer:
          return true
        default:
          return false
      }
    }
  }
  
  public enum Action: Equatable {
    case startReading
    case readingSuccesfully(Libre1Read)
    case readingFailed(String)
    
    case readingSentToServer(Libre1Read)
    case failedSentToServer(String)
  }
  
  public struct Environment {
    let deviceManager: DevicesManager
    let mainQueue: DispatchQueue
    let libre1: Libre1Reader
    
    init(deviceManager: DevicesManager, mainQueue: DispatchQueue) {
      self.deviceManager = deviceManager
      self.mainQueue = mainQueue
      
      self.libre1 = Libre1Reader(readingMessage: "Ready to read", errorMessage: "Failed", completionMessage: "Completed", queue: mainQueue)
    }
  }
}

let libre1ConnectionReducer = Reducer<Libre1Connection.State, Libre1Connection.Action, Libre1Connection.Environment> { state, action, environment in
  struct LongRunningReads: Hashable {}
  struct LongRunningScan: Hashable {}
  
  switch action {
      
    case let .readingSentToServer(reading):
      state.status = .serverSuccess
      return .none
      
    case .startReading:
      if VitalClient.isSetup == false {
        state.status = .notSetup
        return .none
      }
      
      state.status = .reading
      
      let effect = Effect<Libre1Read, Error>.task {
        
        let read = try await environment.libre1.read()
        return read
      }
        .map { Libre1Connection.Action.readingSuccesfully($0) }
        .catch { error in
          return Just(Libre1Connection.Action.readingFailed(error.localizedDescription))
        }
      
      return effect.receive(on: environment.mainQueue).eraseToEffect()
      
    case let .readingSuccesfully(read):
      state.status = .sendingToServer
      state.read = read
      
      let effect = Effect<Void, Error>.task {
        try await VitalClient.shared.timeSeries.post(
          .glucose(read.samples),
          stage: .daily,
          provider: DevicesManager.provider(for: .libre)
        )}
        .map { _ in Libre1Connection.Action.readingSentToServer(read) }
        .catch { error in
          return Just(Libre1Connection.Action.failedSentToServer(error.localizedDescription))
        }
      
      return effect.receive(on: environment.mainQueue).eraseToEffect()
      
    case let .failedSentToServer(reason):
      state.status = .serverFailed
      return .none
      
    case let .readingFailed(reason):
      state.status = .readingFailed
      return .none
  }
}

extension Libre1Connection {
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
              ForEach(viewStore.read?.samples ?? []) { (sample: QuantitySample) in
                
                HStack {
                  VStack {
                    Text(String(format: " %.1f", sample.value))
                      .font(.title)
                      .fontWeight(.medium)
                    
                    Text("\(sample.unit)")
                      .font(.footnote)
                  }
                  
                  Spacer()
                  
                  VStack(alignment: .trailing) {
                    Text("\(sample.startDate.getDay())")
                      .font(.body)
                    Text("\(sample.startDate.getDate())")
                      .font(.body)
                  }
                }
                .padding([.horizontal], 10)
              }
            }
            Button("Scan", action: {
              viewStore.send(.startReading)
            })
            .buttonStyle(LoadingButtonStyle(isLoading: viewStore.isLoading))
            .cornerRadius(5.0)
            .padding([.bottom, .horizontal], 20)
          }
        }
        .environment(\.defaultMinListRowHeight, 25)
        .listStyle(PlainListStyle())
        .background(Color.white)
        .navigationBarTitle(viewStore.device.name, displayMode: .inline)
      }
    }
  }
}
