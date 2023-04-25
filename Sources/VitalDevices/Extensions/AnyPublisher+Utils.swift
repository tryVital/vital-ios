import Combine

extension AnyPublisher {
  static var empty: AnyPublisher {
    Empty().eraseToAnyPublisher()
  }
}

extension Publisher {
  func flatMapLatest<P: Publisher>(_ f: @escaping (Self.Output) -> P) -> AnyPublisher<P.Output, P.Failure> where P.Failure == Self.Failure {
    map(f).switchToLatest().eraseToAnyPublisher()
  }
}
