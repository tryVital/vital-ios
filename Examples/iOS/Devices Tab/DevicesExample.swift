import SwiftUI
import VitalHealthKit
import VitalDevices
import ComposableArchitecture




enum DevicesExample {}

extension DevicesExample {
  struct RootView: View {
    
    let store: Store<AppState, AppAction>
    
    @State private var isPresenting = false
    
    var body: some View {
      WithViewStore(self.store) { viewStore in
        
      }
    }
  }
}

//struct DevicesExample: View {
//
//  @ObservedObject var manager = DevicesManager()
//
//  var body: some View {
//    NavigationView {
//      Form {
//        Section(header: Text("Devices")) {
//
//          if let device = manager.peripheralDiscovery {
//            HStack {
//              Text("\(device.peripheral.id)")
//              Spacer()
//              Button("Connect") {
//                manager.connect(peripheral: device.peripheral)
//              }
//            }
//          }
//
//        }
//      }
//      .listStyle(GroupedListStyle())
//      .navigationBarTitle(Text("Devices"), displayMode: .large)
//    }
//    .onAppear {
//      manager.startSearch(name: "X4")
//    }
//  }
//}
//
