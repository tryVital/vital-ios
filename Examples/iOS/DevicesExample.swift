import SwiftUI
import VitalHealthKit

struct DevicesExample: View {
  var body: some View {
    NavigationView {
      Form {
        Section(header: Text("Devices")) {

        }
      }
      .listStyle(GroupedListStyle())
      .navigationBarTitle(Text("Devices"), displayMode: .large)
    }
  }
}

