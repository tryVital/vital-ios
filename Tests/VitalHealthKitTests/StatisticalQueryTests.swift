import HealthKit
import VitalCore
@testable import VitalHealthKit
import XCTest

class StatisticalQueryTests: XCTestCase {

  func test_respects_cooperative_cancellation() async {
    let dependencies = StatisticsQueryDependencies.live(healthKitStore: HKHealthStore(), vitalStorage: VitalHealthKitStorage(storage: .debug))

    // Run it 100 times to mitigate away any temporary blips that might cause it to pass.
    for _ in 0 ..< 100 {
      let task = Task {
        _ = try await dependencies.executeStatisticalQuery(
          HKQuantityType.quantityType(forIdentifier: .stepCount)!,
          Date().addingTimeInterval(-86400) ..< Date(),
          .daily
        )

        XCTFail("Unexpected return")
      }

      task.cancel()
      _ = await task.result
    }
  }
}
