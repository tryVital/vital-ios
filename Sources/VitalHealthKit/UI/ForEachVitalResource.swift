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
  formatter.dateStyle = .none
  formatter.timeStyle = .long
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
          VStack(alignment: .leading) {
            Text("\(key.rawValue)")
            if let lastUpdated = resource.latestSync?.statuses.last?.timestamp {
              Text(verbatim: dateFormatter.string(from: lastUpdated))
                .foregroundColor(Color.secondary)
                .font(Font.subheadline)
            }
          }
          Spacer()

          if let sync = resource.latestSync {
            icon(for: sync.lastStatus)
          }
        }
      }
      .isDetailLink(false)
    }
    .onReceive(VitalHealthKitClient.shared.syncProgressPublisher().receive(on: RunLoop.main)) { progress in
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
      }

      ForEach(sections) { section in
        Section(header: Text(verbatim: section.id)) {
          ForEach(section.items) { sync in
            let timestamp = sync.statuses.last?.timestamp ?? sync.start
            let time = timeFormatter.string(from: timestamp)
            let duration = durationFormatter.string(from: sync.start, to: timestamp) ?? ""

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

                    Text(verbatim: timeFormatter.string(from: status.timestamp))
                  }
                  .foregroundColor(offset == 0 ? Color.primary : Color.secondary)
                }
                .font(Font.subheadline)
              }

            } label: {
              HStack(alignment: .center) {
                icon(for: sync.lastStatus)

                VStack(alignment: .leading) {
                  Text(verbatim: String(describing: sync.lastStatus))
                  Text(verbatim: sync.tags.map(String.init(describing:)).sorted().joined(separator: ", "))
                    .foregroundColor(Color.secondary)
                    .font(.subheadline)
                }

                Spacer()
                VStack(alignment: .trailing) {
                  Text(verbatim: duration)
                  Text(verbatim: "\(time)")
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
      .foregroundColor(Color.yellow)
      .accessibilityLabel(Text("Cancelled"))
  case .error:
    Image(systemName: "exclamationmark.triangle.fill")
      .foregroundColor(Color.yellow)
      .accessibilityLabel(Text("Error"))
  case .started, .readChunk, .uploadedChunk, .noData, .revalidatingSyncState:
    ProgressView()
      .accessibilityLabel(Text("In Progress"))
  }
}
