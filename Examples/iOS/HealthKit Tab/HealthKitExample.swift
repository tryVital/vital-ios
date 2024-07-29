import SwiftUI
import VitalHealthKit
import HealthKit
import VitalCore

let dateFormatter = {
  let formatter = DateFormatter()
  formatter.dateStyle = .short
  formatter.timeStyle = .none
  formatter.timeZone = TimeZone.autoupdatingCurrent
  formatter.doesRelativeDateFormatting = true
  return formatter
}()

let timeFormatter = {
  let formatter = DateFormatter()
  formatter.dateStyle = .none
  formatter.timeStyle = .long
  formatter.timeZone = TimeZone.autoupdatingCurrent
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
                VStack(alignment: .leading) {
                  Text("\(key.logDescription)")
                  if let lastUpdated = resource.latestSync?.statuses.last?.timestamp {
                    Text(verbatim: dateFormatter.string(from: lastUpdated))
                      .foregroundStyle(Color.secondary)
                      .font(Font.subheadline)
                  }
                }
                Spacer()

                if let sync = resource.latestSync {
                  switch sync.lastStatus {
                  case .completed, .noData:
                    Text("OK")
                  case .started, .readChunk, .uploadedChunk:
                    ProgressView()
                  case .cancelled:
                    Text("Timeout")
                  case .error:
                    Text("Error")
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
      .onReceive(VitalHealthKitClient.shared.syncProgressPublisher().receive(on: RunLoop.main)) { progress in
        self.items = progress.resources
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

      Section {
        ForEach(resource.syncs.reversed()) { sync in
          let timestamp = sync.statuses.last?.timestamp ?? sync.start
          let date = dateFormatter.string(from: timestamp)
          let time = timeFormatter.string(from: timestamp)

          DisclosureGroup {
            VStack(alignment: .leading) {
              ForEach(Array(sync.statuses.reversed().enumerated()), id: \.element.id) { offset, status in
                HStack(alignment: .firstTextBaseline) {
                  if offset == 0 {
                    Image(systemName: "arrowtriangle.right.fill")
                  } else {
                    Image(systemName: "arrowtriangle.up")
                  }

                  Text("\(String(describing: status.type))")
                  Spacer()

                  Text(verbatim: dateFormatter.string(from: status.timestamp))
                }
                .foregroundStyle(offset == 0 ? Color.primary : Color.secondary)
              }
              .font(Font.subheadline)
            }

          } label: {
            HStack(alignment: .center) {
              switch sync.lastStatus {
              case .completed:
                Image(systemName: "checkmark.square.fill")
                  .foregroundStyle(Color.green)
              case .deprioritized:
                Image(systemName: "arrow.uturn.down.square")
                  .foregroundStyle(Color.gray)
              case .cancelled:
                Image(systemName: "minus.square")
                  .foregroundStyle(Color.yellow)
              case .error:
                Image(systemName: "exclamationmark.triangle.fill")
                  .foregroundStyle(Color.yellow)
              case .started, .readChunk, .uploadedChunk, .noData:
                ProgressView()
              }

              VStack(alignment: .leading) {
                Text(verbatim: String(describing: sync.lastStatus))
                Text(verbatim: String(describing: sync.trigger))
                  .foregroundStyle(Color.secondary)
                  .font(.subheadline)
              }

              Spacer()
              VStack(alignment: .trailing) {
                Text(verbatim: "\(time)")
                Text(verbatim: "\(date)")
                  .foregroundStyle(Color.secondary)
                  .font(.subheadline)
              }
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
        let date = dateFormatter.string(from: event.timestamp)
        let time = timeFormatter.string(from: event.timestamp)

        HStack(alignment: .firstTextBaseline) {
          Text("\(String(describing: event.type))")
          Spacer()
          VStack(alignment: .trailing) {
            Text(verbatim: "\(time)")
            Text(verbatim: "\(date)")
              .foregroundStyle(Color.secondary)
              .font(.subheadline)
          }
        }
      }
    }
    .navigationTitle(Text(key.logDescription))
  }
}
