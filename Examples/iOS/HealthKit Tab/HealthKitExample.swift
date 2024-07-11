import SwiftUI
import VitalHealthKit
import HealthKit
import VitalCore

struct HealthKitExample: View {
  @State var permissions: [VitalResource: Bool] = [:]
  @State var pauseSync = VitalHealthKitClient.shared.pauseSynchronization

  var body: some View {
    NavigationView {
      Form {
        Section(header: Text("Permissions")) {
          VStack(spacing: 25) {

            makePermissionRow("Mindful Session", resources: [.vitals(.mindfulSession)], writeResources: [.mindfulSession], permissions: $permissions)
            
            makePermissionRow("Water", resources: [.nutrition(.water)], writeResources: [.water], permissions: $permissions)

            makePermissionRow("Caffeine", resources: [.nutrition(.caffeine)], writeResources: [.caffeine], permissions: $permissions)

            
            makePermissionRow("Profile", resources: [.profile], permissions: $permissions)
            
            makePermissionRow("Body", resources: [.body], permissions: $permissions)
            
            makePermissionRow("Sleep", resources: [.sleep], permissions: $permissions)
            
            makePermissionRow("Activity", resources: [.activity], permissions: $permissions)
            
            makePermissionRow("Workout", resources: [.workout], permissions: $permissions)
            
            makePermissionRow("HeartRate", resources: [.vitals(.heartRate)], permissions: $permissions)

            makePermissionRow("Weight", resources: [.individual(.weight)], permissions: $permissions)

            makePermissionRow("Blood Pressure", resources: [.vitals(.bloodPressure)], permissions: $permissions)

            makePermissionRow("Menstrual Cycle", resources: [.menstrualCycle], permissions: $permissions)

          }
          .buttonStyle(PlainButtonStyle())
        }

        Toggle(isOn: $pauseSync) { Text("Pause Synchronization") }
        
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

        Button("Add mindfuless minutes 10m") {
          Task {
            try await VitalHealthKitClient.shared.write(input: .mindfulSession, startDate: Date().addingTimeInterval(-(60 * 60)), endDate: Date())
          }
        }


      }
      .listStyle(GroupedListStyle())
      .navigationBarTitle(Text("HealthKit"), displayMode: .large)
      .onAppear {
        permissions = Dictionary(
          uniqueKeysWithValues: VitalResource.all.map {
            ($0, VitalHealthKitClient.shared.hasAskedForPermission(resource: $0))
          }
        )
      }
      .onChange(of: self.pauseSync) { pauseSync in
        VitalHealthKitClient.shared.pauseSynchronization = pauseSync
      }
    }
  }
}

@ViewBuilder func makePermissionRow(
  _ text: String,
  resources: [VitalResource],
  writeResources: [WritableVitalResource] = [],
  permissions: Binding<[VitalResource: Bool]>
) -> some View {
  HStack {
    Text(text)
    Spacer()
    

    Button(
      resources.allSatisfy({ permissions.wrappedValue[$0] == true })
        ? "Permission requested"
        : "Request permission"
    ) {
      Task { @MainActor in
        await VitalHealthKitClient.shared.ask(readPermissions: resources, writePermissions: writeResources)

        for resource in resources {
          permissions.wrappedValue[resource] = true
        }
      }
    }
    .buttonStyle(PermissionStyle())
  }
}

