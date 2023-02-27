import SwiftUI

struct ContentView: View {
  @Binding var state: GlucoseMonitorSimulation.ManagerState
  @Binding var isAdvertising: Bool
  @Binding var subscribers: [UUID]
  @Binding var timeline: [GlucoseMonitorSimulation.TimelineEntry]

  var body: some View {
    NavigationSplitView {
      Text(String("state: " + String(describing: state)))
      Text(String("is advertising: " + String(describing: isAdvertising)))
      Text(String("subscribers: " + String(describing: subscribers.count)))

      ForEach(subscribers, id: \.self) { subscriber in
        Text(String(subscriber.uuidString))
      }
    } detail: {
      Table(timeline.reversed()) {
        TableColumn("Date", value: \.date.description)
          .width(min: 150, ideal: 200, max: 250)
        TableColumn("Event", value: \.text)
      }
    }
    .navigationTitle("Timeline")
  }
}

struct ContentView_Previews: PreviewProvider {
  static var previews: some View {
    ContentView(
      state: .constant(.unknown),
      isAdvertising: .constant(true),
      subscribers: .constant([UUID()]),
      timeline: .constant([
        GlucoseMonitorSimulation.TimelineEntry(date: Date(timeIntervalSince1970: 1.0), text: "Entry")
      ])
    )
  }
}
