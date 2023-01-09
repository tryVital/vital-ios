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
            
            makePermissionRow("Water", resources: [.nutrition(.water)], writeResources: [.water])

            makePermissionRow("Caffeine", resources: [.nutrition(.caffeine)], writeResources: [.caffeine])

            
            makePermissionRow("Profile", resources: [.profile])
            
            makePermissionRow("Body", resources: [.body])
            
            makePermissionRow("Sleep", resources: [.sleep])
            
            makePermissionRow("Activity", resources: [.activity])
            
            makePermissionRow("Steps", resources: [.individual(.steps)])
            
            makePermissionRow("Workout", resources: [.workout])
            
            makePermissionRow("HeartRate", resources: [.vitals(.hearthRate)])

            makePermissionRow("Weight", resources: [.individual(.weight)])

          }
          .buttonStyle(PlainButtonStyle())
        }
        
        Button("Add water 1L") {
          Task {
            try await VitalHealthKitClient.shared.write(input: .water(milliliters: 1000), startDate: Date(), endDate: Date())
          }
        }

        Button("Add caffeine 20g") {
          Task {
            try await VitalHealthKitClient.shared.write(input: .caffeine(grams: 20), startDate: Date(), endDate: Date())
          }
        }

      }
      .listStyle(GroupedListStyle())
      .navigationBarTitle(Text("HealthKit"), displayMode: .large)
    }
  }
}

@ViewBuilder func makePermissionRow(_ text: String, resources: [VitalResource], writeResources: [WritableVitalResource] = []) -> some View {
  HStack {
    Text(text)
    Spacer()
    
    if VitalHealthKitClient.shared.hasAskedForPermission(resource: resources[0]) {
      Button("Permission requested") {}
        .disabled(true)
        .buttonStyle(PermissionStyle())
    } else {
      Button("Request Permission") {
        Task {
          await VitalHealthKitClient.shared.ask(readPermissions: resources, writePermissions: writeResources)
        }
      }
      .buttonStyle(PermissionStyle())
    }
  }
}

