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

public struct LoadingButtonStyle: ButtonStyle {
  let isLoading: Bool
  
  public init(isLoading: Bool = false) {
    self.isLoading = isLoading
  }
  
  public func makeBody(configuration: Configuration) -> some View {
    Group {
      if isLoading {
        ProgressView().progressViewStyle(CircularProgressViewStyle(tint: Color.white))
      } else {
        configuration.label.foregroundColor(.white)
      }
    }
    .frame(maxWidth: .infinity, idealHeight: 30, alignment: .center)
    .padding()
    .background(configuration.isPressed ? Color.gray : Color.accentColor)
    .disabled(isLoading)
  }
}


public struct RegularButtonStyle: ButtonStyle {
  let isDisabled: Bool
  
  public init(isDisabled: Bool = false) {
    self.isDisabled = isDisabled
  }
  
  public func makeBody(configuration: Configuration) -> some View {
    
    if isDisabled {
      return configuration.label.foregroundColor(.white)
        .frame(maxWidth: .infinity, idealHeight: 30, alignment: .center)
        .padding()
        .background(Color.gray)
    }
    
   
    return configuration.label.foregroundColor(.white)
      .frame(maxWidth: .infinity, idealHeight: 30, alignment: .center)
      .padding()
      .background(configuration.isPressed ? Color.gray : .accentColor)
  }
}
