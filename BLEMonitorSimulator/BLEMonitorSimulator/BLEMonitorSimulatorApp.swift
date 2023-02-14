import SwiftUI

@main
struct BLEMonitorSimulatorApp: App {
  @StateObject var simulation = GlucoseMonitorSimulation()

  var body: some Scene {
    WindowGroup {
      ContentView(
        state: $simulation.state,
        isAdvertising: $simulation.isAdvertising,
        subscribers: $simulation.subscribers,
        timeline: $simulation.timeline
      )
      .onAppear {
        simulation.start()
      }
    }
  }
}
