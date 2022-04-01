import Foundation
import CombineCoreBluetooth


public class DevicesTest {
  private let manager: CentralManager
  var cancellables = Set<AnyCancellable>()
  
  init() {
    self.manager = .live()
  }
  
  public func startSearch() {
    self.manager.scanForPeripherals(withServices: nil).sink { peripheral in
      
    }
    .store(in: &cancellables)
  }
}
