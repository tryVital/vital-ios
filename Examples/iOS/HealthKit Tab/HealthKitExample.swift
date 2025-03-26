import SwiftUI
import VitalHealthKit
import HealthKit
import VitalCore

extension EnvironmentValues {
  @Entry var permissions: Binding<[VitalResource: PermissionStatus]> = Binding(get: { [:] }, set: { _ in })
  @Entry var requestRestrictionDemo: Binding<Bool> = Binding(get: { false }, set: { _ in })
}

struct HealthKitExample: View {
  @State var permissions: [VitalResource: PermissionStatus] = [:]
  @State var pauseSync = VitalHealthKitClient.shared.pauseSynchronization
  @State var requestRestrictionDemo = false

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
            Toggle(isOn: $requestRestrictionDemo) {
              VStack(alignment: .leading) {
                Text("Request Restriction Demo")
                Text("Only activeEnergyBurned, stepCount and sleepAnalysis").font(.footnote)
              }
            }

            makePermissionRow("Profile", resources: [.profile])
            
            makePermissionRow("Body", resources: [.body])
            
            makePermissionRow("Sleep", resources: [.sleep])
            
            makePermissionRow("Activity", resources: [.activity])
            
            makePermissionRow("Workout", resources: [.workout])

            makePermissionRow("Menstrual Cycle", resources: [.menstrualCycle])

            makePermissionRow("Meal", resources: [.meal])

            makePermissionRow("HeartRate", resources: [.vitals(.heartRate)])

            makePermissionRow("Electrocardiogram", resources: [.electrocardiogram])

            makePermissionRow("AFib Burden", resources: [.afibBurden])

            makePermissionRow("Heart Rate Alert", resources: [.heartRateAlert])

            makePermissionRow("Respiratory Rate", resources: [.vitals(.respiratoryRate)])

            makePermissionRow("Blood Pressure", resources: [.vitals(.bloodPressure)])

            makePermissionRow("Temperature", resources: [.vitals(.temperature)])

            makePermissionRow("Weight", resources: [.individual(.weight)])

            makePermissionRow("Mindful Session", resources: [.vitals(.mindfulSession)], writeResources: [.mindfulSession])

            makePermissionRow("Water", resources: [.nutrition(.water)], writeResources: [.water])

            makePermissionRow("Caffeine", resources: [.nutrition(.caffeine)], writeResources: [.caffeine])

            makePermissionRow("Stand Hour", resources: [.standHour], permissions: $permissions)

            makePermissionRow("Stand Time", resources: [.standTime], permissions: $permissions)

            makePermissionRow("Sleep Apnea Alert", resources: [.sleepApneaAlert], permissions: $permissions)

            makePermissionRow("Slee Breathing Disturbance", resources: [.sleepBreathingDisturbance], permissions: $permissions)

            makePermissionRow("Wheelchair Push", resources: [.wheelchairPush], permissions: $permissions)

            makePermissionRow("Forced Expiratory Volume", resources: [.forcedExpiratoryVolume1], permissions: $permissions)

            makePermissionRow("Forced Vital Capacity", resources: [.forcedVitalCapacity], permissions: $permissions)

            makePermissionRow("Peak Expiratory Flow Rate", resources: [.peakExpiratoryFlowRate], permissions: $permissions)

            makePermissionRow("Inhaler Usage", resources: [.inhalerUsage], permissions: $permissions)

            makePermissionRow("Fall", resources: [.fall], permissions: $permissions)

            makePermissionRow("UV Exposure", resources: [.uvExposure], permissions: $permissions)

            makePermissionRow("Daylight Exposure", resources: [.daylightExposure], permissions: $permissions)

            makePermissionRow("Handwashing", resources: [.handwashing], permissions: $permissions)

            makePermissionRow("Basal Body Temperature", resources: [.basalBodyTemperature], permissions: $permissions)

          }
          .buttonStyle(PlainButtonStyle())
          .environment(\.requestRestrictionDemo, $requestRestrictionDemo)
          .environment(\.permissions, $permissions)
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
        } catch let error {
          print(error)
        }
      }
      .onChange(of: self.pauseSync) { pauseSync in
        VitalHealthKitClient.shared.pauseSynchronization = pauseSync
      }
    }
  }
}

struct makePermissionRow: View {

  let text: String
  let resources: [VitalResource]
  let writeResources: [WritableVitalResource]

  init(_ text: String, resources: [VitalResource], writeResources: [WritableVitalResource] = []) {
    self.text = text
    self.resources = resources
    self.writeResources = writeResources
  }

  @SwiftUI.Environment(\.permissions) var permissions
  @SwiftUI.Environment(\.requestRestrictionDemo) var requestRestrictionDemo

  var body: some View {
    HStack {
      Text(text)
      Spacer()

      Button(
        resources.allSatisfy({ permissions.wrappedValue[$0] == .asked })
        ? "Permission asked"
        : "Ask for permission"
      ) {
        Task {
          let allowlist: Set<HKObjectType>?

          if requestRestrictionDemo.wrappedValue {
            allowlist = [
              HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
              HKObjectType.quantityType(forIdentifier: .stepCount)!,
              HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!,
            ]
          } else {
            allowlist = nil
          }

          let outcome = await VitalHealthKitClient.shared.ask(
            readPermissions: resources,
            writePermissions: writeResources,
            dataTypeAllowlist: allowlist
          )

          print(outcome)

          if outcome == .success {
            for resource in resources {
              permissions.wrappedValue[resource] = .asked
            }
          }
        }
      }
      .buttonStyle(PermissionStyle())
    }
  }
}
