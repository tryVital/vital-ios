import SwiftUI
import VitalHealthKit
import VitalDevices
import ComposableArchitecture
import NukeUI

enum DevicesExample {}

extension DevicesExample {
  public struct State: Equatable {
    let devices: [DeviceModel]
    var selection: Identified<String, DeviceConnection.State>?
    
    init() {
      self.devices = DevicesManager.brands().flatMap(DevicesManager.devices(for:))
      self.selection = nil
    }
  }
  
  public enum Action: Equatable {
    case deviceConnection(DeviceConnection.Action)
    case navigateToDeviceConnection(String?)
  }
  public struct Environment {}
}

private let reducer = Reducer<DevicesExample.State, DevicesExample.Action, DevicesExample.Environment> { state, action, _ in
  
  switch action {
    case .deviceConnection:
      return .none
      
    case .navigateToDeviceConnection(nil):
      state.selection = nil
      return .none
      
    case let .navigateToDeviceConnection(.some(id)):
      for device in state.devices {
        if device.id == id {
          state.selection = .init(.init(device: device), id: id)
        }
      }
      
      return .none
  }
}
let devicesStore = Store(initialState: DevicesExample.State(), reducer: reducer, environment: DevicesExample.Environment())


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
      ForEach(viewStore.devices) { device in
        NavigationLink(
          destination: IfLetStore(
            self.store.scope(
              state: \.selection?.value,
              action: DevicesExample.Action.deviceConnection
            ),
            then: DeviceConnection.RootView.init(store:))
          ,
          tag: device.id,
          selection: viewStore.binding(
            get: \.selection?.id,
            send: DevicesExample.Action.navigateToDeviceConnection
          )
        ) {
          HStack {
            LazyImage(source: url(for: device), resizingMode: .aspectFit)
              .frame(width: 100, height: 100, alignment: .leading)
            
            VStack(alignment: .leading) {
              Text("\(device.name)")
                .font(.headline)
                .fontWeight(.medium)
              
              Text("\(name(for: device.kind))")
                .font(.subheadline)
                .fontWeight(.medium)
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

