public struct BluetoothRACPError: Error {
  public let code: Int

  public init(code: Int) {
    self.code = code
  }
}

public struct BluetoothError: Error {
  public let message: String

  public init(message: String) {
    self.message = message
  }
}
