import SwiftUI

public struct SyncProgressView: View {
  @Environment(\.presentationMode) var presentationMode

  public init() {}

  public var body: some View {
    NavigationView {
      List {
        Section {
          ForEachVitalResource()
        } header: {
          Text("Resources")
        }

        Section {
          CoreSDKStateView()
        } header: {
          Text("Core SDK State")
        }
      }
      .navigationTitle(Text("Sync Progress"))
      .navigationBarItems(
        leading: Button {
          presentationMode.wrappedValue.dismiss()
        } label: {
          Text("Close")
        }
      )
    }
  }
}
