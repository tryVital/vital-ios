import SwiftUI
import VitalCore
import ComposableArchitecture
import VitalHealthKit

@main
struct ExampleApp: App {
  var body: some Scene {
    WindowGroup {
      WithViewStore(settingsStore) { viewStore in
        TabView {
          #if DEBUG
          HealthKitExample()
            .tabItem {
              Image(systemName: "suit.heart")
              Text("HealthKit")
            }
            .tag(0)
          #endif
          DevicesExample.RootView(store: devicesStore)
            .tabItem {
              Image(systemName: "laptopcomputer.and.iphone")
              Text("Devices")
            }
            .tag(1)
          
          LinkCreation.RootView(store: linkCreationStore)
            .tabItem {
              Image(systemName: "link")
              Text("Link")
            }
            .tag(2)
          
          Settings.RootView(store: settingsStore)
            .tabItem {
              Image(systemName: "gear")
              Text("Settings")
            }
            .tag(3)
        }
        .onAppear {
          viewStore.send(.start)
        }
      }
    }
  }
}
