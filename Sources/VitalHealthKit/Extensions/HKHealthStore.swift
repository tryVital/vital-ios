import Foundation
import HealthKit
import CryptoKit

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

extension HKQueryAnchor {
  var hashForLog: String {
    guard
      let data = (try? NSKeyedArchiver.archivedData(withRootObject: self, requiringSecureCoding: false)),
      data.isEmpty == false
    else { return "<nil>" }

    var hasher = SHA256()
    hasher.update(data: data)

    // Let's just take first 8 characters since this is for logging purpose. Collision is very
    // unlikely.
    return String(hasher.finalize().hexStr.prefix(8))
  }
}

extension HKSampleType {
  static let knownPrefixes = ["HKQuantityTypeIdentifier", "HKCategoryTypeIdentifier"]

  var shortenedID: String {
    let identifier = self.identifier

    for pre in Self.knownPrefixes where identifier.hasPrefix(pre) {
      return String(identifier.dropFirst(pre.count))
    }

    return identifier
  }
}
