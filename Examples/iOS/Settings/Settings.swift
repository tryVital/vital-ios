import SwiftUI
import VitalHealthKit
import VitalDevices
import VitalCore
import ComposableArchitecture
import NukeUI
import Combine

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
    
    var canGenerateUserId: Bool {
      return credentials.clientSecret.isEmpty == false &&
      credentials.clientId.isEmpty == false
    }
  }
  
  enum Action: BindableAction, Equatable {
    case binding(BindingAction<State>)
    case start
    case save
    case setup
    case genetareUserId
    case successfulGenerateUserId(UUID)
    case failedGeneratedUserId
  }
  
  class Environment {
    init() {}
  }
}

private let reducer = Reducer<Settings.State, Settings.Action, Settings.Environment> { state, action, _ in
  switch action {
      
    case .failedGeneratedUserId:
      return .none
      
    case let .successfulGenerateUserId(userId):
      state.credentials.userId = userId.uuidString
      return .none
      
    case .genetareUserId:
      let date = Date()
      let string = DateFormatter().string(from: date)
      
      let clientUserId = "user_generated_demo_\(date)"
      let payload = CreateUserRequest.init(clientUserId: clientUserId)
      
      let effect = Effect<CreateUserResponse, Error>.task {
        let userResponse = try await VitalNetworkClient.shared.user.create(payload)
        return userResponse
      }
      
      let outcome: Effect<Settings.Action, Never> = effect.map { (result: CreateUserResponse) -> Settings.Action in
        return .successfulGenerateUserId(result.userId)
      }
      .catch { error in
        return Just(Settings.Action.failedGeneratedUserId)
      }
      .receive(on: DispatchQueue.main)
      .eraseToEffect()
      
      let setup: Effect<Settings.Action, Never> = .init(value: .setup).receive(on: DispatchQueue.main).eraseToEffect()
      
      
      return Effect.concatenate(setup, outcome)
      
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
          environment: .sandbox(.us)
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
      
      return .none//.init(value: .setup)
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
    @FocusState private var activeKeyboard: Bool
    
    
    var body: some View {
      WithViewStore(self.store) { viewStore in
        NavigationView {
          Form {
            Section(content: {
              HStack {
                Text("Client ID")
                  .fontWeight(.bold)
                TextField("Client ID", text: viewStore.binding(\.$credentials.clientId))
                  .disableAutocorrection(true)
                  .focused($activeKeyboard)
              }
              
              HStack {
                Text("Client Secret")
                  .fontWeight(.bold)
                TextField("Client Secret", text: viewStore.binding(\.$credentials.clientSecret))
                  .disableAutocorrection(true)
                  .focused($activeKeyboard)
              }
              
              HStack {
                Text("User ID (UUID-4)")
                  .fontWeight(.bold)
                TextField("User ID (UUID-4)", text: viewStore.binding(\.$credentials.userId))
                  .disableAutocorrection(true)
                  .focused($activeKeyboard)
              }
            }, footer: {
              VStack(spacing: 5) {
                
                Spacer()
                Button("Generate userId", action: {
                  viewStore.send(.genetareUserId)
                })
                .buttonStyle(RegularButtonStyle(isDisabled: viewStore.canGenerateUserId == false))
                .cornerRadius(5.0)
                .padding([.bottom], 20)
                
                
                Button("Save", action: {
                  self.activeKeyboard = false
                  viewStore.send(.save)
                })
                .buttonStyle(RegularButtonStyle(isDisabled: viewStore.canSave == false))
                .cornerRadius(5.0)
                .padding([.bottom], 20)
              }
            })
          }
          .onAppear {
            UIScrollView.appearance().keyboardDismissMode = .onDrag
          }
          .navigationBarTitle(Text("Settings"), displayMode: .large)
        }
      }
    }
  }
}


