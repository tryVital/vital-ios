import SwiftUI
import VitalHealthKit

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
        DevicesExample()
          .tabItem {
            Image(systemName: "laptopcomputer.and.iphone")
            Text("Devices")
          }
          .tag(1)
      }
      .onAppear {
        VitalHealthKitClient.configure(
          clientId: "xyz",
          clientSecret: "zys",
          environment: .sandbox(.us)
        )
        
        VitalHealthKitClient.set(userId: "xyz-zyx")
      }
    }
  }
}
