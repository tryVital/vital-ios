import SwiftUI
import VitalHealthKit
import HealthKit
import VitalCore


struct HealthKitExample: View {
  @State var permissions: [VitalResource: PermissionStatus] = [:]
  @State var pauseSync = VitalHealthKitClient.shared.pauseSynchronization

  var body: some View {
    NavigationView {
      Form {
        Section(header: Text("Sync Progress")) {
          ForEachVitalResource()
        }

        Section(header: Text("Core SDK State")) {
          CoreSDKStateView()
        }

        Section(header: Text("Permissions")) {
          VStack(spacing: 25) {

            makePermissionRow("Profile", resources: [.profile], permissions: $permissions)
            
            makePermissionRow("Body", resources: [.body], permissions: $permissions)
            
            makePermissionRow("Sleep", resources: [.sleep], permissions: $permissions)
            
            makePermissionRow("Activity", resources: [.activity], permissions: $permissions)
            
            makePermissionRow("Workout", resources: [.workout], permissions: $permissions)

            makePermissionRow("Menstrual Cycle", resources: [.menstrualCycle], permissions: $permissions)

            makePermissionRow("Meal", resources: [.meal], permissions: $permissions)

            makePermissionRow("HeartRate", resources: [.vitals(.heartRate)], permissions: $permissions)

            makePermissionRow("Electrocardiogram", resources: [.electrocardiogram], permissions: $permissions)

            makePermissionRow("AFib Burden", resources: [.afibBurden], permissions: $permissions)

            makePermissionRow("Heart Rate Alert", resources: [.heartRateAlert], permissions: $permissions)

            makePermissionRow("Respiratory Rate", resources: [.vitals(.respiratoryRate)], permissions: $permissions)

            makePermissionRow("Blood Pressure", resources: [.vitals(.bloodPressure)], permissions: $permissions)

            makePermissionRow("Temperature", resources: [.vitals(.temperature)], permissions: $permissions)

            makePermissionRow("Weight", resources: [.individual(.weight)], permissions: $permissions)

            makePermissionRow("Mindful Session", resources: [.vitals(.mindfulSession)], writeResources: [.mindfulSession], permissions: $permissions)

            makePermissionRow("Water", resources: [.nutrition(.water)], writeResources: [.water], permissions: $permissions)

            makePermissionRow("Caffeine", resources: [.nutrition(.caffeine)], writeResources: [.caffeine], permissions: $permissions)

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

        Button("Show Sync Progress View") {
          SyncProgressViewController.presentInKeyWindow()
        }


      }
      .listStyle(GroupedListStyle())
      .navigationBarTitle(Text("HealthKit"), displayMode: .large)
      .task {
        do {
          self.permissions = try await VitalHealthKitClient.shared.permissionStatus(for: VitalResource.all)
        } catch let _ {
          
        }
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
  permissions: Binding<[VitalResource: PermissionStatus]>
) -> some View {
  HStack {
    Text(text)
    Spacer()
    

    Button(
      resources.allSatisfy({ permissions.wrappedValue[$0] == .asked })
        ? "Permission asked"
        : "Ask for permission"
    ) {
      Task { @MainActor in
        await VitalHealthKitClient.shared.ask(readPermissions: resources, writePermissions: writeResources)

        for resource in resources {
          permissions.wrappedValue[resource] = .asked
        }
      }
    }
    .buttonStyle(PermissionStyle())
  }
}
