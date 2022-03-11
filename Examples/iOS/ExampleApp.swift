import SwiftUI
import VitalHealthKit

@main
struct ExampleApp: App {
  var body: some Scene {
    WindowGroup {
      HomeView()
        .onAppear {
          
          VitalHealthKitClient.configure(
            clientId: "xyz",
            clientSecret: "zys",
            environment: .sandbox
          )
          
          VitalHealthKitClient.set(userId: "xyz-zyx")
        }
    }
  }
}
