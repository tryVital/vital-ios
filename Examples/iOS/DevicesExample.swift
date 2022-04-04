import SwiftUI
import VitalHealthKit
import VitalDevices

struct DevicesExample: View {
  
  @ObservedObject var manager = DevicesManager()
  
  var body: some View {
    NavigationView {
      Form {
        Section(header: Text("Devices")) {
          
          if let device = manager.peripheralDiscovery {
            HStack {
              Text("\(device.peripheral.id)")
              Button("Connect") {
                manager.connect(peripheral: device.peripheral)
              }
            }
          }

        }
      }
      .listStyle(GroupedListStyle())
      .navigationBarTitle(Text("Devices"), displayMode: .large)
    }
    .onAppear {
      manager.startSearch(name: "X4")
    }
  }
}

