import SwiftUI
import VitalHealthKit

struct HomeView: View {
  var body: some View {
    NavigationView {
      Form {
        Section(header: Text("Permissions")) {
          VStack(spacing: 25) {
            
            makePermissionRow("Profile", domains: [.profile])
            
            makePermissionRow("Body", domains: [.body])
            
            makePermissionRow("Sleep", domains: [.sleep])
            
            makePermissionRow("Activity", domains: [.activity])
            
            makePermissionRow("Workout", domains: [.workout])

          }
          .buttonStyle(PlainButtonStyle())
        }
      }
      .listStyle(GroupedListStyle())
      .navigationBarTitle(Text("Vital Home"), displayMode: .large)
    }
  }
}


@ViewBuilder func makePermissionRow(_ text: String, domains: [Domain]) -> some View {
  HStack {
    Text(text)
    Spacer()
    Button("Request Permission") {
      VitalHealthKitClient.shared.ask(for: domains) { completion in
        print(completion)
      }
    }
    .buttonStyle(PermissionStyle())
  }
}
