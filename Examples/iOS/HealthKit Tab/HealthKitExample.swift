import SwiftUI
import VitalHealthKit

struct HealthKitExample: View {
  var body: some View {
    NavigationView {
      Form {
        Section(header: Text("Permissions")) {
          VStack(spacing: 25) {
            
            makePermissionRow("Profile", resources: [.profile])
            
            makePermissionRow("Body", resources: [.body])
            
            makePermissionRow("Sleep", resources: [.sleep])
            
            makePermissionRow("Activity", resources: [.activity])
            
            makePermissionRow("Workout", resources: [.workout])

            makePermissionRow("Vitals - Glucose", resources: [.vitals(.glucose)])

          }
          .buttonStyle(PlainButtonStyle())
        }
      }
      .listStyle(GroupedListStyle())
      .navigationBarTitle(Text("HealthKit"), displayMode: .large)
    }
  }
}


@ViewBuilder func makePermissionRow(_ text: String, resources: [VitalResource]) -> some View {
  HStack {
    Text(text)
    Spacer()
    Button("Request Permission") {
      VitalHealthKitClient.shared.ask(for: resources) { completion in
        print(completion)
      }
    }
    .buttonStyle(PermissionStyle())
  }
}
