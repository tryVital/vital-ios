import Foundation

public struct ProfilePatch: Equatable, Encodable, Hashable {
  public enum BiologicalSex: String, Encodable, Hashable {
    case male = "male"
    case female = "female"
    case other = "other"
    case notSet = "not_set"
  }
  
  public let biologicalSex: BiologicalSex?
  public let dateOfBirth: Date?
  public let height: Int?
  public let timeZone: String?
  
  public init(
    biologicalSex: ProfilePatch.BiologicalSex?,
    dateOfBirth: Date?,
    height: Int?,
    timeZone: String?
  ) {
    self.biologicalSex = biologicalSex
    self.dateOfBirth = dateOfBirth
    self.height = height
    self.timeZone = timeZone
  }

  public var id: String {
    let biologicalSex = String(describing: self.biologicalSex?.rawValue)
    let dateOfBirth = String(describing: self.dateOfBirth)
    let height = String(describing: self.height?.description)
    let timeZone = String(describing: self.timeZone)

    return "\(biologicalSex)_\(dateOfBirth)_\(height)_\(timeZone)"
  }
}


