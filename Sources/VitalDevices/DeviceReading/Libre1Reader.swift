import Foundation
import VitalCore

public class Libre1Reader {
  
  private let readingMessage: String
  private let errorMessage: String
  private let completionMessage: String
  private let queue: DispatchQueue
  
  public init(
    readingMessage: String,
    errorMessage: String,
    completionMessage: String,
    queue: DispatchQueue
  ) {
    self.readingMessage = readingMessage
    self.errorMessage = errorMessage
    self.completionMessage = completionMessage
    self.queue = queue
  }
  
  public func read() async throws -> (Libre1Read) {
    /// We need to retain the NFC object, otherwise it's released inside `withCheckedThrowingContinuation`
    var nfc: NFC!
    
    let payload: (Sensor, [Glucose]) = try await withCheckedThrowingContinuation { continuation in
      nfc = NFC(
        readingMessage: readingMessage,
        errorMessage: errorMessage,
        completionMessage: completionMessage,
        continuation: continuation,
        queue: queue
      )
      
      nfc.startSession()
    }
    
    let samples = payload.1.map(QuantitySample.init)
    let device = Libre1Device.init(sensor: payload.0)
    
    return Libre1Read(samples: samples, device: device)
  }
}

public struct Libre1Read: Equatable {
  public let samples: [QuantitySample]
  public let device: Libre1Device
}

public struct Libre1Device: Equatable {
  public enum State: Equatable   {
    case unknown
    case notActivated
    case warmingUp
    case active
    case expired
    case shutdown
    case failure
    
    init(_ sensorState: SensorState) {
      switch sensorState {
        case .unknown:
          self = .unknown
        case .notActivated:
          self = .notActivated
        case .warmingUp:
          self = .warmingUp
        case .active:
          self = .active
        case .expired:
          self = .expired
        case .shutdown:
          self = .shutdown
        case .failure:
          self = .failure
      }
    }
  }
  
  public let serial: String
  public let maxLife: Int
  public let age: Int
  public let state: State
  
  init(sensor: Sensor) {
    
    self.serial = sensor.serial
    self.maxLife = sensor.maxLife
    self.age = sensor.age
    self.state = State(sensor.state)
  }
}
