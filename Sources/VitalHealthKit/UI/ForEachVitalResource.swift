import SwiftUI
import VitalCore

private let dateFormatter = {
  let formatter = DateFormatter()
  formatter.dateStyle = .short
  formatter.timeStyle = .none
  formatter.timeZone = TimeZone.autoupdatingCurrent
  formatter.doesRelativeDateFormatting = true
  return formatter
}()

private let timeFormatter = {
  let formatter = DateFormatter()
  formatter.setLocalizedDateFormatFromTemplate("HH:mm")
  formatter.timeZone = TimeZone.autoupdatingCurrent
  return formatter
}()

private let timeWithSecondsFormatter = {
  let formatter = DateFormatter()
  formatter.setLocalizedDateFormatFromTemplate("HH:mm:ss")
  formatter.timeZone = TimeZone.autoupdatingCurrent
  return formatter
}()

private let durationFormatter = {
  let formatter = DateComponentsFormatter()
  formatter.unitsStyle = .abbreviated
  return formatter
}()

/// A SwiftUI View that expands into a self-updating list of Vital SDK resources with their latest sync status.
///
/// Use it in a container view, e.g. SwiftUI `List`.
///
/// ```swift
/// var body: some View {
///   List {
///       Section(header: Text("Sync Progress")) {
///           ForEachVitalResource()
///       }
///   }
/// }
/// ```
public struct ForEachVitalResource: View {
  @State var items: [(key: BackfillType, value: SyncProgress.Resource)] = []
  @State var nextSchedule: Date? = nil

  public init() {}

  @ViewBuilder
  public var body: some View {
    ForEach($items, id: \.key) { item in
      let (key, resource) = item.wrappedValue

      NavigationLink {
        ResourceProgressDetailView(key: key, resource: item[keyPath: \.value])

      } label: {
        HStack {
          if let sync = resource.latestSync {
            icon(for: sync.lastStatus)
              .frame(width: 22, height: 22)
          }

          VStack(alignment: .leading) {
            Text("\(key.rawValue)")
            if let tags = resource.latestSync?.tags {
              Text(verbatim: "\(tags.map(String.init(describing:)).sorted().joined(separator: ", "))")
                .foregroundColor(Color.secondary)
                .font(Font.subheadline)
            }
          }

          Spacer()
          VStack(alignment: .trailing) {
            if let lastUpdated = resource.latestSync?.statuses.last?.timestamp {
              Text(verbatim: timeFormatter.string(from: lastUpdated))

              Text(verbatim: dateFormatter.string(from: lastUpdated))
                .foregroundColor(Color.secondary)
                .font(Font.subheadline)
            }
          }
        }
      }
      .isDetailLink(false)
    }
    .onReceive(
      VitalHealthKitClient.shared.syncProgressPublisher()
        .throttle(for: .milliseconds(100), scheduler: RunLoop.main, latest: true)
        .receive(on: RunLoop.main)
    ) { progress in
      self.items = progress.backfillTypes
        .sorted(by: { $0.key.rawValue.compare($1.key.rawValue) == .orderedAscending })
      self.nextSchedule = SyncProgressReporter.shared.nextSchedule()
    }

    Menu {
      Button("Force Upload", systemImage: "chevron.up.square") {
        Task { @MainActor in
          try? await SyncProgressReporter.shared.report()
          self.nextSchedule = SyncProgressReporter.shared.nextSchedule()
        }

      }

    } label: {
      HStack {
        VStack(alignment: .leading) {
          Text("Sync Log")
          if let nextSchedule = nextSchedule {
            Text(verbatim: "Next upload: " + dateFormatter.string(from: nextSchedule) + " " + timeFormatter.string(from: nextSchedule))
              .foregroundColor(Color.secondary)
              .font(Font.subheadline)
          }
        }
        Spacer()
        Image(systemName: "ellipsis.circle")
      }
    }

    Button("Force Sync") {
      VitalHealthKitClient.shared.syncData()
    }
  }
}

public struct CoreSDKStateView: View {

  @State var status: VitalClient.Status = []
  @State var currentUserId: String? = nil
  @State var identifiedExternalUser: String? = nil

  public init() {}

  public var body: some View {
    Group {
      VStack(alignment: .leading) {
        Text("Vital User ID")

        Text("\(currentUserId ?? "-")")
          .font(Font.system(.footnote, design: .monospaced))
      }

      VStack(alignment: .leading) {
        Text("Identified External User")

        Text("\(identifiedExternalUser ?? "-")")
          .font(Font.system(.footnote, design: .monospaced))
      }

      VStack(alignment: .leading) {
        Text("Core SDK Status")

        Text("\(status.description)")
          .font(Font.system(.footnote, design: .monospaced))
      }
    }
    .onReceive(VitalClient.statusDidChange.receive(on: RunLoop.main).prepend(())) {
      self.status = VitalClient.status
      self.currentUserId = VitalClient.currentUserId
      self.identifiedExternalUser = VitalClient.identifiedExternalUser
    }
  }
}

public struct HealthSDKStateView: View {

  enum PerformingAction {
    case connect
    case disconnect
  }

  @State var connectionStatus: VitalHealthKitClient.ConnectionStatus = .autoConnect
  @State var performingAction: PerformingAction? = nil
  @State var error: Error? = nil

  public init() {}

  public var body: some View {
    Group {
      VStack(alignment: .leading) {
        Text("Connection Status")

        Text("\(connectionStatus)")
          .font(Font.system(.footnote, design: .monospaced))
      }

      if self.connectionStatus != .autoConnect {
        Button {
          self.performingAction = connectionStatus == .disconnected ? .connect : .disconnect

        } label: {
          if performingAction != nil {
            ProgressView()

          } else {
            switch connectionStatus {
            case .autoConnect:
              EmptyView()

            case .connected, .connectionPaused:
              Text("Disconnect")

            case .disconnected:
              Text("Connect")
            }
          }
        }
        .disabled(self.performingAction != nil)
      }
    }
    .onReceive(VitalHealthKitClient.shared.connectionStatusPublisher().receive(on: RunLoop.main)) { connectionStatus in
      self.connectionStatus = connectionStatus
    }
    .onChange(of: self.performingAction) { action in
      Task { @MainActor in
        do {
          switch self.performingAction {
          case .connect:
            try await VitalHealthKitClient.shared.connect()
          case .disconnect:
            try await VitalHealthKitClient.shared.disconnect()
          case nil:
            return
          }
        } catch let error {
          self.error = error
        }
        self.performingAction = nil
      }
    }
    .alert(
      isPresented: Binding(get: { self.error != nil }, set: { isPresented in self.error = isPresented ? self.error : nil })
    ) {
      Alert(title: Text("Error"))
    }
  }
}


private struct ResourceProgressDetailView: View {

  struct ItemSection: Identifiable {
    let id: String
    let items: [SyncProgress.Sync]
  }

  let key: BackfillType
  @Binding var resource: SyncProgress.Resource

  var sections: [ItemSection] {
    let calendar = GregorianCalendar(timeZone: .current)
    let groups = Dictionary(grouping: resource.syncs) { calendar.floatingDate(of: $0.start) }
    let sortedGroups = groups.sorted(by: { $0.key > $1.key })

    return sortedGroups.map { date, items in
      ItemSection(
        id: dateFormatter.string(from: calendar.startOfDay(date)),
        items: items.reversed()
      )
    }
  }

  var body: some View {
    List {
      Section {
        NavigationLink {
          ResourceSystemEventView(key: key, resource: $resource)

        } label: {
          Text("System Events")
        }
        .isDetailLink(false)

        if let firstAsked = resource.firstAsked {
          HStack(alignment: .center) {
            Text("First Asked")
            Spacer()
            Text("\(dateFormatter.string(from: firstAsked)) \(timeFormatter.string(from: firstAsked))")
          }
        }

        HStack(alignment: .center) {
          Text("Total Data Count")
          Spacer()
          Text("\(resource.dataCount)")
        }
      }

      ForEach(sections) { section in
        Section(header: Text(verbatim: section.id)) {
          ForEach(section.items) { sync in
            let timestamp = sync.statuses.last?.timestamp ?? sync.start
            let time = timeFormatter.string(from: timestamp)
            let duration = durationFormatter.string(from: sync.start, to: timestamp) ?? ""

            DisclosureGroup {
              VStack(alignment: .leading) {

                if let errorDetails = sync.statuses.last?.errorDetails {
                  Text("Cause: \(errorDetails)")
                    .font(.footnote)
                }

                ForEach(Array(sync.statuses.reversed().enumerated()), id: \.element.id) { offset, status in
                  HStack(alignment: .firstTextBaseline) {
                    if offset == 0 {
                      Image(systemName: "arrowtriangle.right.fill")
                    } else {
                      Image(systemName: "arrowtriangle.up")
                    }

                    Text("\(String(describing: status.type))")
                    Spacer()

                    Text(verbatim: timeWithSecondsFormatter.string(from: status.timestamp))
                  }
                  .foregroundColor(offset == 0 ? Color.primary : Color.secondary)
                }
                .font(Font.subheadline)
              }

            } label: {
              HStack(alignment: .center) {
                icon(for: sync.lastStatus)
                  .frame(width: 22, height: 22)

                VStack(alignment: .leading) {
                  if sync.lastStatus.isInProgress {
                    Text(verbatim: String(describing: sync.lastStatus))
                  } else {
                    Text(verbatim: "\(String(describing: sync.lastStatus)) (\(sync.dataCount) uploaded)")
                  }

                  Text(verbatim: sync.tags.map(String.init(describing:)).sorted().joined(separator: ", "))
                    .foregroundColor(Color.secondary)
                    .font(.subheadline)
                }

                Spacer()
                VStack(alignment: .trailing) {
                  Text(verbatim: "\(time)")
                  Text(verbatim: duration)
                    .foregroundColor(Color.secondary)
                    .font(.subheadline)
                }
              }
            }
          }
        }
      }
    }
    .navigationTitle(Text(key.rawValue))
  }
}

private struct ResourceSystemEventView: View {
  let key: BackfillType
  @Binding var resource: SyncProgress.Resource

  public var body: some View {
    List {
      ForEach(resource.systemEvents.reversed()) { event in
        let date = dateFormatter.string(from: event.timestamp)
        let time = timeFormatter.string(from: event.timestamp)

        HStack(alignment: .firstTextBaseline) {
          VStack(alignment: .leading) {
            Text("\(String(describing: event.type))")
            Text(verbatim: "Count: \(event.count)")
              .foregroundColor(Color.secondary)
              .font(.subheadline)

            if let errorDetails = event.errorDetails {
              Text("Cause: \(errorDetails)")
                .font(.footnote)
            }
          }
          Spacer()
          VStack(alignment: .trailing) {
            Text(verbatim: "\(time)")
            Text(verbatim: "\(date)")
              .foregroundColor(Color.secondary)
              .font(.subheadline)
          }
        }
      }
    }
    .navigationTitle(Text(key.rawValue))
  }
}

@ViewBuilder
private func icon(for status: SyncProgress.SyncStatus) -> some View {
  switch status {
  case .completed:
    Image(systemName: "checkmark.square.fill")
      .foregroundColor(Color.green)
      .accessibilityLabel(Text("OK"))
  case .deprioritized:
    Image(systemName: "arrow.uturn.down.square")
      .foregroundColor(Color.gray)
      .accessibilityLabel(Text("Deprioritized"))
  case .cancelled:
    Image(systemName: "minus.square")
      .foregroundColor(Color.gray)
      .accessibilityLabel(Text("Cancelled"))
  case .timedOut:
    Image(systemName: "minus.square")
      .foregroundColor(Color.gray)
      .accessibilityLabel(Text("Timed Out"))
  case .expectedError:
    Image(systemName: "minus.square")
      .foregroundColor(Color.gray)
      .accessibilityLabel(Text("Expected Error"))
  case .connectionPaused:
    Image(systemName: "minus.square")
      .foregroundColor(Color.gray)
      .accessibilityLabel(Text("Connection Paused"))
  case .connectionDestroyed:
    Image(systemName: "minus.square")
      .foregroundColor(Color.gray)
      .accessibilityLabel(Text("Connection Destroyed"))
  case .error:
    Image(systemName: "exclamationmark.triangle.fill")
      .foregroundColor(Color.yellow)
      .accessibilityLabel(Text("Error"))
  case .started, .readChunk, .uploadedChunk, .noData, .revalidatingSyncState:
    ProgressView()
      .accessibilityLabel(Text("In Progress"))
  }
}
