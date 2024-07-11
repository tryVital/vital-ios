public struct Source: Equatable, Codable {
  public let provider: String
  public let type: SourceType
  public let appId: String?

  public init(provider: String, type: SourceType, appId: String?) {
    self.provider = provider
    self.type = type
    self.appId = appId
  }
}
