import Foundation
import HealthKit

extension HKHealthStore {
  internal func patched_dateOfBirthComponents() throws -> DateComponents? {
    do {
      return try dateOfBirthComponents()
    } catch let error as NSError {
      guard error.code == 0 && error.domain == "Foundation._GenericObjCError"
        else { throw error }
      return nil
    }
  }
}
