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
  
  public func read() async throws -> [QuantitySample] {
    /// We need to retain the NFC here, otherwise it's released inside `withCheckedThrowingContinuation`
    var nfc: NFC!
    
    let values: [Glucose] = try await withCheckedThrowingContinuation { continuation in
      nfc = NFC(
        readingMessage: readingMessage,
        errorMessage: errorMessage,
        completionMessage: completionMessage,
        continuation: continuation,
        queue: queue
      )
      
      nfc.startSession()
    }
    
    return values.map(QuantitySample.init)
  }
}
