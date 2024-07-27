import SwiftUI
import VitalHealthKit
import HealthKit
import VitalCore

let dateFormatter = {
  let formatter = DateFormatter()
  formatter.dateStyle = .short
  formatter.timeStyle = .short
  formatter.timeZone = TimeZone.autoupdatingCurrent
  return formatter
}()

let dateComponentFormatter = {
  let formatter = DateComponentsFormatter()
  formatter.allowedUnits = [.minute, .second]
  formatter.unitsStyle = .positional
  formatter.zeroFormattingBehavior = .pad
  return formatter
}()

struct HealthKitExample: View {
  @State var permissions: [VitalResource: Bool] = [:]
  @State var pauseSync = VitalHealthKitClient.shared.pauseSynchronization

  @State var items: [(key: VitalResource, value: SyncProgress.Resource)] = []

  var body: some View {
    NavigationView {
      Form {
        Section(header: Text("Sync Progress")) {
          ForEach($items, id: \.key) { item in
            let (key, resource) = item.wrappedValue

            NavigationLink {
              ResourceSyncProgressView(key: key, resource: item[keyPath: \.value])

            } label: {
              HStack {
                Text("\(key.logDescription)")
                Spacer()

                if let sync = resource.latestSync {
                  switch sync.lastStatus {
                  case .completed, .noData:
                    Text("OK")
                  case .started, .readChunk, .uploadedChunk:
                    ProgressView()
                  case .timeout:
                    Text("Timeout")
                  case .deprioritized:
                    Text("Deprioritized")
                  }
                }
              }
            }
            .isDetailLink(false)
          }
        }

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
      .onReceive(Timer.publish(every: 0.10, on: RunLoop.main, in: .default).autoconnect()) { _ in
        self.items = VitalHealthKitClient.shared.syncProgress.resources
          .sorted(by: { $0.key.logDescription.compare($1.key.logDescription) == .orderedAscending })
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

struct ResourceSyncProgressView: View {
  let key: VitalResource
  @Binding var resource: SyncProgress.Resource

  var body: some View {
    List {
      Section {
        NavigationLink {
          ResourceSystemEventView(key: key, resource: $resource)

        } label: {
          Text("System Events")
        }
        .isDetailLink(false)
      }

      ForEach(resource.syncs.reversed()) { sync in
        Section {
          let start = dateFormatter.string(from: sync.start)
          let startTimeZone = dateFormatter.timeZone.abbreviation(for: sync.start) ?? ""
          let end = sync.end.map { end in
            (
              dateFormatter.string(from: end),
              dateFormatter.timeZone.abbreviation(for: end) ?? ""
            )
          }

          VStack(alignment: .leading) {
            if let end = end {
              HStack(alignment: .center) {
                Text("End")
                Spacer()
                Text(verbatim: "\(end.0) \(end.1)")
              }
            }

            HStack(alignment: .center) {
              if sync.lastStatus.isInProgress {
                ProgressView()
              }

              Text("Start")
              Spacer()
              Text(verbatim: "\(start) \(startTimeZone)")
            }
            .foregroundStyle(end != nil ? Color.secondary : Color.primary)
          }

          VStack(alignment: .leading) {
            ForEach(Array(sync.statuses.reversed().enumerated()), id: \.element.id) { offset, status in
              HStack(alignment: .firstTextBaseline) {
                Text("\(String(describing: status.type))")
                Spacer()

                Text(verbatim: dateComponentFormatter.string(from: status.timestamp.timeIntervalSince(sync.start)) ?? "")
              }
              .foregroundStyle(offset == 0 ? Color.primary : Color.secondary)
            }
          }
        }
      }
    }
    .navigationTitle(Text(key.logDescription))
  }
}

struct ResourceSystemEventView: View {
  let key: VitalResource
  @Binding var resource: SyncProgress.Resource

  var body: some View {
    List {
      ForEach(resource.systemEvents.reversed()) { event in
        let time = dateFormatter.string(from: event.timestamp)
        let timeZone = dateFormatter.timeZone.abbreviation(for: event.timestamp) ?? ""

        HStack(alignment: .firstTextBaseline) {
          Text("\(String(describing: event.type))")
          Spacer()
          Text(verbatim: "\(time) \(timeZone)")
        }
      }
    }
    .navigationTitle(Text(key.logDescription))
  }
}
