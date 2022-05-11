import Foundation

class Libre1Reader {
  
  private let nfc: NFC
  
  init(
    title: String,
    completion: String,
    queue: DispatchQueue
  ) {
    self.nfc = NFC()
    }
}
