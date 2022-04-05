import SwiftUI
import VitalHealthKit
import VitalDevices
import ComposableArchitecture
import NukeUI

enum DeviceConnection {}

extension DeviceConnection {
  public struct State: Equatable {
    enum Status: String {
      case connected = "Connected"
      case searching = "Searching"
      case failed = "Failed"
      case noneFound = "None found"
    }
    
    let device: DeviceModel
    var status: Status
    
    init(device: DeviceModel) {
      self.device = device
      self.status = .searching
    }
  }
  
  public enum Action: Equatable {}
  public struct Environment {}
}

private let deviceConnectionReducer = Reducer<DeviceConnection.State, DeviceConnection.Action, DeviceConnection.Environment>.empty


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
