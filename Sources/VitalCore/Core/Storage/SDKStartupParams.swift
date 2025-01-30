import Foundation

internal struct SDKStartupParams: Codable {
  var externalUserId: String?
  var userId: UUID

  // Since this is a gist, the embedded API Key is stored without file protection.
  //
  // This is not a security issue in our eyes, since the API Key is discouraged for production usage.
  //
  // For SDK users using it in production, they most likely have the key embedded directly in their
  // app binary, which is as (in)secure as storing it in a gist without file protection.
  var authStrategy: ConfigurationStrategy
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
