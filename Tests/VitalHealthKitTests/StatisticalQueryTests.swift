import HealthKit
import VitalCore
@testable import VitalHealthKit
import XCTest

class StatisticalQueryTests: XCTestCase {

  func test_executeStatisticalQuery_respects_cooperative_cancellation() async {
    let dependencies = StatisticsQueryDependencies.live(healthKitStore: HKHealthStore())

    // Run it 100 times to mitigate away any temporary blips that might cause it to pass.
    for _ in 0 ..< 100 {
      let task = Task {
        _ = try await dependencies.executeStatisticalQuery(
          HKQuantityType.quantityType(forIdentifier: .stepCount)!,
          Date().addingTimeInterval(-86400) ..< Date(),
          .daily,
          nil
        )

        XCTFail("Unexpected return")
      }

      task.cancel()
      let result = await task.result

      XCTAssertThrowsError(try result.get()) { error in
        XCTAssertTrue(error is CancellationError)
      }
    }
  }
}
