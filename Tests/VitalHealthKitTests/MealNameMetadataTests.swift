import XCTest
import HealthKit

@testable import VitalHealthKit

class MealNameMetadataTests: XCTestCase {

  func testFoodNameAliasIsCopiedToMealKey() {
    let normalized = normalizeMealNameMetadata(["foodName": "Amelaine Bowl", "quantity": "1"])
    XCTAssertEqual(normalized["Meal"], "Amelaine Bowl")
    XCTAssertEqual(normalized["foodName"], "Amelaine Bowl")
    XCTAssertEqual(normalized["quantity"], "1")
  }

  func testFoodTypeAliasIsCopiedToMealKey() {
    let normalized = normalizeMealNameMetadata([HKMetadataKeyFoodType: "Banana"])
    XCTAssertEqual(normalized["Meal"], "Banana")
  }

  func testRecognisedMealKeysAreLeftUntouched() {
    for key in ["Meal", "HKFoodMeal", "meal"] {
      let metadata = [key: "Breakfast", "foodName": "Oats"]
      XCTAssertEqual(normalizeMealNameMetadata(metadata), metadata)
    }
  }

  func testMetadataWithoutAliasIsUnchanged() {
    let metadata = ["HKMetadataKeySyncIdentifier": "abc"]
    XCTAssertEqual(normalizeMealNameMetadata(metadata), metadata)
    XCTAssertEqual(normalizeMealNameMetadata([:]), [:])
  }

  func testEmptyAliasValueIsIgnored() {
    let metadata = ["foodName": ""]
    XCTAssertEqual(normalizeMealNameMetadata(metadata), metadata)
  }
}
