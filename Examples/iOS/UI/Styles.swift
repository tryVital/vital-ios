import SwiftUI

struct PermissionStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .padding(5)
      .foregroundColor(configuration.isPressed ? Color.white : Color.accentColor)
      .background(configuration.isPressed ? Color.accentColor : Color.white)
      .cornerRadius(8)
      .overlay(
        RoundedRectangle(cornerRadius: 8)
          .stroke(
            Color.accentColor,
            lineWidth: 1
          )
      )
  }
}
