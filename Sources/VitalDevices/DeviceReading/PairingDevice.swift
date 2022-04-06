import Combine

public protocol DevicePairable {
  func pair(device: ScannedDevice) -> AnyPublisher<Void, Error>
}
