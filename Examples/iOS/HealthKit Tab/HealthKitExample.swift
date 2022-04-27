import SwiftUI
import VitalHealthKit
import HealthKit
import VitalCore

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

            makePermissionRow("Glucose", resources: [.vitals(.glucose)])
            
            makePermissionRow("BloodPressure", resources: [.vitals(.bloodPressure)])

          }
          .buttonStyle(PlainButtonStyle())
        }
      }
      .listStyle(GroupedListStyle())
      .navigationBarTitle(Text("HealthKit"), displayMode: .large)
      .onAppear {
        print("HealthKitExample-onAppear")
      }
    }
  }
}

@ViewBuilder func makePermissionRow(_ text: String, resources: [VitalResource]) -> some View {
  HStack {
    Text(text)
    Spacer()
    
    if hasAskedForPermission(resource: resources[0], store: HKHealthStore()) {
      Button("Permission requested") {}
        .disabled(true)
        .buttonStyle(PermissionStyle())
    } else {
      Button("Request Permission") {
        Task {
          await VitalHealthKitClient.shared.ask(for: resources)
        }
      }
      .buttonStyle(PermissionStyle())
    }
  }
}
