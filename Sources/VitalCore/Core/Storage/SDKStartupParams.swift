
internal struct SDKStartupParams: Codable {
  var externalUserId: String?
}

internal struct SDKStartupParamsStorage {
  static let live = SDKStartupParamsStorage()

  init() {}

  func get() -> SDKStartupParams? {
    return VitalGistStorage.shared.get(SDKStartupParamsGistKey.self)
  }

  func set(_ newValue: SDKStartupParams?) throws {
    try VitalGistStorage.shared.set(newValue, for: SDKStartupParamsGistKey.self)
  }
}

enum SDKStartupParamsGistKey: GistKey {
  typealias T = SDKStartupParams
  static var identifier: String { "vital_startup_params" }
}
