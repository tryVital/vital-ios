import SwiftUI
import VitalCore

@main
struct ExampleApp: App {
  var body: some Scene {
    WindowGroup {
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
      }
      .onAppear {
        VitalNetworkClient.configure(
          clientId: "xyz",
          clientSecret: "xyz",
          environment: .dev(.us)
        )
        
        let userId = UUID(uuidString: "xyz")!
        VitalNetworkClient.setUserId(userId)
      }
    }
  }
}
