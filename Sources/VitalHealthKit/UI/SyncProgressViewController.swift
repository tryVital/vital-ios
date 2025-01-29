import UIKit
import SwiftUI

public class SyncProgressViewController: UIHostingController<SyncProgressView> {
  public init() {
    super.init(rootView: SyncProgressView())
  }

  @MainActor public required dynamic init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  @MainActor public static func presentInKeyWindow() {
    guard let keyWindow = UIApplication.shared.connectedScenes.lazy
      .compactMap({ ($0 as? UIWindowScene)?.windows.first { $0.isKeyWindow } })
      .first
    else {
      return
    }

    keyWindow.rootViewController?.present(
      SyncProgressViewController(),
      animated: true,
      completion: nil
    )
  }
}
