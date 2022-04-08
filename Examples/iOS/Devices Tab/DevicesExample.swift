import SwiftUI
import VitalHealthKit
import VitalDevices
import ComposableArchitecture
import NukeUI

enum DevicesExample {}

extension DevicesExample {
  public struct State: Equatable {
    let devices: [DeviceModel]
    var deviceConnection: DeviceConnection.State? = nil
    
    init() {
      self.devices = DevicesManager.brands().flatMap(DevicesManager.devices(for:))
    }
  }
  
  public enum Action: Equatable {
    case deviceConnection(DeviceConnection.Action)
    case navigateToDeviceConnection(String?)
  }
  
  public struct Environment {
    let deviceManager: DevicesManager
    let mainQueue: DispatchQueue
  }
}

private let reducer = Reducer<DevicesExample.State, DevicesExample.Action, DevicesExample.Environment> { state, action, _ in
  switch action {
    case .deviceConnection:
      return .none
      
    case .navigateToDeviceConnection(nil):
      state.deviceConnection = nil
      return .none
      
    case let .navigateToDeviceConnection(.some(id)):
      for device in state.devices {
        if device.id == id {
          state.deviceConnection = DeviceConnection.State(device: device)
        }
      }
      
      return .none
  }
}
  .presents(deviceConnectionReducer, cancelEffectsOnDismiss: true, state: \.deviceConnection, action: /DevicesExample.Action.deviceConnection) { env in
    DeviceConnection.Environment(deviceManager: env.deviceManager, mainQueue: env.mainQueue)
  }


let devicesStore = Store(
  initialState: DevicesExample.State(),
  reducer: reducer,
  environment: DevicesExample.Environment(deviceManager: DevicesManager(), mainQueue: DispatchQueue.main)
)

extension DevicesExample {
  struct RootView: View {
    
    let store: Store<State, Action>
    
    var body: some View {
      WithViewStore(self.store) { viewStore in
        NavigationView {
          List {
            Text("Select a source bellow to get started")
            self.render(viewStore)
          }
          .environment(\.defaultMinListRowHeight, 25)
          .listStyle(PlainListStyle())
          .background(Color.white)
          .navigationBarTitle(Text("Devices"), displayMode: .large)
        }
      }
    }
    
    @ViewBuilder func render(_ viewStore: ViewStore<State, Action>) -> some View {
      ForEach(viewStore.devices) { (device: DeviceModel) in        
        NavigationLink(
          destination: IfLetStore(
            self.store.scope(
              state: \.deviceConnection,
              action: DevicesExample.Action.deviceConnection
            ),
            then: DeviceConnection.RootView.init(store:))
          ,
          tag: device.id,
          selection: viewStore.binding(
            get: \.deviceConnection?.device.id,
            send: DevicesExample.Action.navigateToDeviceConnection
          )
        ) {
          HStack {
            LazyImage(source: url(for: device), resizingMode: .aspectFit)
              .frame(width: 100, height: 100, alignment: .leading)
            
            VStack(alignment: .leading) {
              Text("\(device.name)")
                .font(.headline)
              
              Text("\(name(for: device.kind))")
                .font(.subheadline)
                .foregroundColor(.gray)
            }
            
            Spacer()
          }
        }
        .padding()
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets())
      }
    }
  }
}

