/// Taken from here: https://stackoverflow.com/a/55684308/491239
extension Sequence {
  func unique<T: Hashable>(by keyPath: KeyPath<Element, T>) -> [Element] {
    var unique = Set<T>()
    return filter { unique.insert($0[keyPath: keyPath]).inserted }
  }
}
