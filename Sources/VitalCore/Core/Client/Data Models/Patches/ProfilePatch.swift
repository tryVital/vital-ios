import Foundation

public struct ProfilePatch: Equatable, Encodable {
  public enum BiologicalSex: String, Encodable {
    case male
    case female
    case other
    case notSet
  }
  
  public let biologicalSex: BiologicalSex?
  public let dateOfBirth: Date?
  public let height: Int?
  
  public init(
    biologicalSex: ProfilePatch.BiologicalSex?,
    dateOfBirth: Date?,
    height: Int?
  ) {
    self.biologicalSex = biologicalSex
    self.dateOfBirth = dateOfBirth
    self.height = height
  }
}
