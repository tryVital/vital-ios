import SwiftUI
import VitalCore
import ComposableArchitecture

@main
struct ExampleApp: App {
  var body: some Scene {
    WindowGroup {
      WithViewStore(settingsStore) { viewStore in
        TabView {
          HealthKitExample()
            .tabItem {
              Image(systemName: "suit.heart")
              Text("HealthKit")
            }
            .tag(0)
          DevicesExample.RootView(store: devicesStore)
            .tabItem {
              Image(systemName: "laptopcomputer.and.iphone")
              Text("Devices")
            }
            .tag(1)
          
          Settings.RootView(store: settingsStore)
            .tabItem {
              Image(systemName: "gear")
              Text("Settings")
            }
            .tag(2)
        }
        .onAppear {
          viewStore.send(.start)
        }
      }
    }
  }
}
