public struct Source: Equatable, Decodable {
  public let provider: String
  public let type: SourceType
  public let appId: String?
}
