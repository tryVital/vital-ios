import SwiftUI
import VitalHealthKit
import VitalDevices
import ComposableArchitecture
import NukeUI

enum DeviceConnection {}

extension DeviceConnection {
  public struct State: Equatable {
    let device: DeviceModel

    init(device: DeviceModel) {
      self.device = device
    }
  }
  
  public enum Action: Equatable {}
  public struct Environment {}
}

private let reducer = Reducer<DeviceConnection.State, DeviceConnection.Action, DeviceConnection.Environment>.empty

//let deviceConnection = Store(
//  initialState: DeviceConnection.State(), reducer: reducer, environment: DevicesExample.Environment())

extension DeviceConnection {
  struct RootView: View {
    
    let store: Store<State, Action>
    
    var body: some View {
      WithViewStore(self.store) { viewStore in
          List {
            
          }
          .environment(\.defaultMinListRowHeight, 25)
          .listStyle(PlainListStyle())
          .background(Color.white)
          .navigationBarTitle(viewStore.device.name, displayMode: .inline)
        }

    }
  }
}
