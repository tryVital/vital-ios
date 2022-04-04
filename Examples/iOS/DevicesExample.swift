import SwiftUI
import VitalHealthKit
import VitalDevices

struct DevicesExample: View {
  
  let device = DevicesManager()
  
  var body: some View {
    NavigationView {
      Form {
        Section(header: Text("Devices")) {

        }
      }
      .listStyle(GroupedListStyle())
      .navigationBarTitle(Text("Devices"), displayMode: .large)
    }
    .onAppear {
      device.startSearch()
    }
  }
}

