import SwiftUI
import VitalHealthKit
import VitalCore

let userId = UUID(uuidString: "xxx")!
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
          clientId: "xxx",
          clientSecret: "xxx",
          environment: .dev(.us)
        )
        
         VitalNetworkClient.setUserId(userId)
      }
    }
  }
}
