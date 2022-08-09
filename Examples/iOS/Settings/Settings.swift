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
    var apiKey: String = ""
    var userId: String = ""
    
    var environment: VitalCore.Environment = .sandbox(.us)
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
      return credentials.apiKey.isEmpty == false &&
      UUID(uuidString: credentials.userId) != nil
    }
    
    var canGenerateUserId: Bool {
      return credentials.apiKey.isEmpty == false
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
    case setEnvironment(VitalCore.Environment)
  }
  
  class Environment {
    init() {}
  }
}

let settingsReducer = Reducer<Settings.State, Settings.Action, Settings.Environment> { state, action, _ in
  switch action {
      
    case let .setEnvironment(environment):
      state.credentials.environment = environment
      return .none
      
    case .failedGeneratedUserId:
      return .none
      
    case let .successfulGenerateUserId(userId):
      state.credentials.userId = userId.uuidString
      return .init(value: .save)
      
    case .genetareUserId:
      let date = Date()
      let string = DateFormatter().string(from: date).replacingOccurrences(of: " ", with: "_")
      
      let clientUserId = "user_generated_demo_\(date)"
      let payload = CreateUserRequest(clientUserId: clientUserId)
      
      let effect = Effect<CreateUserResponse, Error>.task {
        let userResponse = try await VitalClient.shared.user.create(clientUserId: clientUserId)
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
        state.credentials.apiKey.isEmpty == false
      {        
        VitalClient.configure(
          apiKey: state.credentials.apiKey,
          environment: state.credentials.environment,
          configuration: .init(logsEnable: true)
        )
      }
      
      if
        state.credentials.userId.isEmpty == false,
        let userId = UUID(uuidString: state.credentials.userId)
      {
        VitalClient.setUserId(userId)
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
        state.credentials.apiKey.isEmpty == false,
        state.credentials.userId.isEmpty == false
      {
        let value = try? JSONEncoder().encode(state.credentials)
        UserDefaults.standard.setValue(value, forKey: "credentials")
      }
      
      return .init(value: .setup)
  }
}
  .binding()

extension Settings {
  struct RootView: View {
    
    let store: Store<State, Action>
    @FocusState private var activeKeyboard: Bool
    
    
    var body: some View {
      WithViewStore(self.store) { viewStore in
        NavigationView {
          Form {
            
            Section("Configuration") {
              
              HStack {
                Text("API Key")
                  .fontWeight(.bold)
                TextField("API Key", text: viewStore.binding(\.$credentials.apiKey))
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
            }
            
            Section(content: {
              Row(title: "Sandbox - EU", isSelected: viewStore.credentials.environment == .sandbox(.eu))
                .onTapGesture {
                  viewStore.send(.setEnvironment(.sandbox(.eu)))
                }
              
              Row(title: "Sandbox - US", isSelected: viewStore.credentials.environment == .sandbox(.us))
                .onTapGesture {
                  viewStore.send(.setEnvironment(.sandbox(.us)))
                }
              
              Row(title: "Production - EU", isSelected: viewStore.credentials.environment == .production(.eu))
                .onTapGesture {
                  viewStore.send(.setEnvironment(.production(.eu)))
                }
              
              Row(title: "Production - US", isSelected: viewStore.credentials.environment == .production(.us))
                .onTapGesture {
                  viewStore.send(.setEnvironment(.production(.us)))
                }
            }, footer: {
              VStack(spacing: 5) {
                Button("Generate userId", action: {
                  viewStore.send(.genetareUserId)
                })
                .disabled(viewStore.canGenerateUserId == false)
                .buttonStyle(RegularButtonStyle(isDisabled: viewStore.canGenerateUserId == false))
                .cornerRadius(5.0)
                .padding([.bottom], 10)
                
                Button("Save", action: {
                  self.activeKeyboard = false
                  viewStore.send(.save)
                })
                .disabled(viewStore.canSave == false)
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


extension Settings {
    struct Row: View {
      
      let title: String
      let isSelected: Bool
      
      var body: some View {
        HStack(spacing: 10) {
          Text(title).font(.callout)
          Spacer()
          if isSelected {
            Image(systemName: "checkmark.circle")
              .resizable()
              .frame(width: 15, height: 15)
              .foregroundColor(.accentColor)
          }
        }
        .padding([.top, .bottom], 15)
        .contentShape(Rectangle())
      }
    }
}
