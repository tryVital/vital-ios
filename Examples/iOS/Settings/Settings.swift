import SwiftUI
import VitalHealthKit
import VitalDevices
import VitalCore
import ComposableArchitecture
import NukeUI

enum Settings {}

extension Settings {
  struct Credentials: Equatable, Codable {
    var clientId: String = ""
    var clientSecret: String = ""
    var userId: String = ""
  }
  
  struct State: Equatable {
    enum Status: Equatable {
      case start
      case failed(String)
      case saved
    }
    
    @BindableState var credentials: Credentials = .init()
    var status: Status = .start
    
    var canSave: Bool {
      return credentials.clientSecret.isEmpty == false &&
      credentials.clientId.isEmpty == false &&
      UUID(uuidString: credentials.userId) != nil
    }
  }
  
  enum Action: BindableAction, Equatable {
    case binding(BindingAction<State>)
    case start
    case save
    case setup
  }
  
  class Environment {
    init() {}
  }
}

private let reducer = Reducer<Settings.State, Settings.Action, Settings.Environment> { state, action, _ in
  switch action {
    case .binding:
      return .none
      
    case .setup:
      if
        state.credentials.clientId.isEmpty == false,
        state.credentials.clientSecret.isEmpty == false
      {
        VitalNetworkClient.configure(
          clientId: state.credentials.clientId,
          clientSecret: state.credentials.clientSecret,
          environment: .dev(.us)
        )
      }
      
      if state.credentials.userId.isEmpty == false {
        VitalNetworkClient.setUserId(UUID(uuidString: state.credentials.userId)!)
      }
      
      return .none
      
    case .start:
      if
        let data = UserDefaults.standard.data(forKey: "credentials"),
        let decoded = try? JSONDecoder().decode(Settings.Credentials.self, from: data)
      {
        state.credentials = decoded
      }
      
      return .init(value: .setup)
      
    case .save:
      if
        state.credentials.clientId.isEmpty == false,
        state.credentials.clientSecret.isEmpty == false,
        state.credentials.userId.isEmpty == false
      {
        let value = try? JSONEncoder().encode(state.credentials)
        UserDefaults.standard.setValue(value, forKey: "credentials")
      }
      
      return .init(value: .setup)
  }
}
  .binding()


let settingsStore = Store(
  initialState: Settings.State(),
  reducer: reducer,
  environment: Settings.Environment()
)

extension Settings {
  struct RootView: View {
    
    let store: Store<State, Action>
    
    var body: some View {
      WithViewStore(self.store) { viewStore in
        Form {
          Section(content: {
            TextField("Client ID", text: viewStore.binding(\.$credentials.clientId))
              .disableAutocorrection(true)
            
            TextField("Client Secret", text: viewStore.binding(\.$credentials.clientSecret))
              .disableAutocorrection(true)
            
            TextField("User ID (UUID-4)", text: viewStore.binding(\.$credentials.userId))
              .disableAutocorrection(true)
          }, footer: {
            Button("Save", action: {
              viewStore.send(.save)
            })
            .buttonStyle(RegularButtonStyle(isDisabled: viewStore.canSave == false))
            .padding([.bottom], 20)
          })
        }
      }
    }
  }
}


