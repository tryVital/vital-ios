import SwiftUI
import VitalHealthKit

struct HomeView: View {
  var body: some View {
    NavigationView {
      Form {
        Section(header: Text("Permissions")) {
          VStack(spacing: 25) {
            HStack {
              Text("Body")
              Spacer()
              Button("Request Permission") {
                VitalHealthKitClient.shared.ask(for: [.body]) { completion in
                  print(completion)
                }
              }
              .buttonStyle(PermissionStyle())
            }
            
            HStack {
              Text("Sleep")
              Spacer()
              Button("Request Permission") {
                VitalHealthKitClient.shared.ask(for: [.sleep]) { completion in
                  print(completion)
                }
              }
              .buttonStyle(PermissionStyle())
            }
          }
          .buttonStyle(PlainButtonStyle())
        }
      }
      .listStyle(GroupedListStyle())
      .navigationBarTitle(Text("Vital Home"), displayMode: .large)
    }
  }
}




