/// From here: https://gist.github.com/sindresorhus/4bbb54da90aa5df0345bc889df82979f
public protocol IdentifiableByHashable: Identifiable {}

extension IdentifiableByHashable where Self: Hashable {
  public var id: Int { hashValue }
}
