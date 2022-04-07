import Foundation

public struct CreateConnectionSourceRequest: Encodable {
  public let userId: UUID
  public let providerId: String?
  
  public init(userId: UUID, providerId: String? = nil) {
    self.userId = userId
    self.providerId = providerId
  }
}
