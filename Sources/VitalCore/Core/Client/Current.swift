internal enum Current {
  static var secureStorage = VitalSecureStorage(keychain: .live)
  static var startupParamsStorage = SDKStartupParamsStorage()
}
