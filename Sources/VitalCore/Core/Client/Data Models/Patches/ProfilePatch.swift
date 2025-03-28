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
  public let wheelchairUse: Bool?

  public init(
    biologicalSex: ProfilePatch.BiologicalSex?,
    dateOfBirth: Date?,
    height: Int?,
    timeZone: String?,
    wheelchairUse: Bool?
  ) {
    self.biologicalSex = biologicalSex
    self.dateOfBirth = dateOfBirth
    self.height = height
    self.timeZone = timeZone
    self.wheelchairUse = wheelchairUse
  }
}


