import SwiftUI
import VitalHealthKit
import VitalDevices
@_spi(VitalTesting) import VitalCore
import ComposableArchitecture
import NukeUI
import Combine

enum Settings {}

extension Settings {
  enum AuthMode: String, Hashable, Codable, Identifiable {
    case apiKey
    case userJWTDemo

    var id: AuthMode { self }

    var configureActionTitle: String {
      switch self {
      case .apiKey:
        return "Configure SDK"
      case .userJWTDemo:
        return "Sign-in with Vital Token"
      }
    }
  }

  struct Credentials: Equatable, Codable {
    var apiKey: String = ""
    var userId: String = ""
    var authMode: AuthMode = .apiKey
    
    var environment: VitalCore.Environment = .sandbox(.us)
  }
  
  struct State: Equatable {
    enum Status: Equatable {
      case start
      case failed(String)
      case saved
    }
    
    @BindingState var credentials: Credentials = .init()

    var sdkUserId: String? = nil
    var sdkIsConfigured: Bool = false

    var status: Status = .start
    @BindingState var alert: ComposableArchitecture.AlertState<Action>?

    var hasValidAPIKey: Bool {
      credentials.apiKey.isEmpty == false
    }

    var hasValidUserId: Bool {
      UUID(uuidString: credentials.userId) != nil
    }
    
    var canConfigureSDK: Bool {
      hasValidAPIKey && hasValidUserId && sdkIsConfigured == false
    }

    var canGenerateUserId: Bool {
      hasValidAPIKey && credentials.userId.isEmpty
    }
  }
  
  enum Action: BindableAction, Equatable {
    case binding(BindingAction<State>)
    case start
    case configureSDK
    case resetSDK
    case didConfigureSDK
    case didResetSDK
    case genetareUserId
    case successfulGenerateUserId(UUID)
    case failedGeneratedUserId(String)
    case setEnvironment(VitalCore.Environment)
    case nop
    case dismissAlert
  }
  
  class Environment {
    init() {}
  }
}

let settingsReducer = Reducer<Settings.State, Settings.Action, Settings.Environment> { state, action, _ in
  func saveCredentials(in state: Settings.State) {
    guard state.hasValidAPIKey || state.hasValidUserId else { return }
    let value = try? JSONEncoder().encode(state.credentials)
    UserDefaults.standard.setValue(value, forKey: "credentials")
  }

  defer {
    switch action {
    case .configureSDK, .genetareUserId, .failedGeneratedUserId, .start, .didResetSDK, .didConfigureSDK:
      state.sdkIsConfigured = VitalClient.status.contains(.configured)
      state.sdkUserId = VitalClient.currentUserId
    default:
      break
    }
  }

  switch action {
      
    case .nop:
      return .none

    case .dismissAlert:
      state.alert = nil
      return .none
      
    case let .setEnvironment(environment):
      state.credentials.environment = environment
      saveCredentials(in: state)
      return .none
      
    case let .failedGeneratedUserId(error):
      state.alert = AlertState<Settings.Action> {
        TextState("Error")
      } actions: {
        ButtonState(role: ButtonStateRole.cancel, action: .send(nil)) {
          TextState("OK")
        }
      } message: {
        TextState("Failed to create user: \(error)")
      }
      return .none
      
    case let .successfulGenerateUserId(userId):
      state.credentials.userId = userId.uuidString
      saveCredentials(in: state)
      return .none
      
    case .genetareUserId:
      guard state.canGenerateUserId else {
        return .none
      }

      state.credentials.userId = ""

      let date = Date()
      let string = DateFormatter().string(from: date).replacingOccurrences(of: " ", with: "_")
      
      let clientUserId = "user_generated_demo_\(date)"
      let payload = CreateUserRequest(clientUserId: clientUserId)
      let credentials = state.credentials
      
      let effect = Effect<CreateUserResponse, Error>.task {
        let controlPlane = VitalClient.controlPlane(apiKey: credentials.apiKey, environment: credentials.environment)
        let userResponse = try await controlPlane.createUser(clientUserId: clientUserId)
        return userResponse
      }
      
      return effect.map { (result: CreateUserResponse) -> Settings.Action in
        return .successfulGenerateUserId(result.userId)
        }
        .catch { error in
          return Just(Settings.Action.failedGeneratedUserId(String(describing: error)))
        }
        .receive(on: DispatchQueue.main)
        .eraseToEffect()
      
    case .binding:
      saveCredentials(in: state)
      return .none
      
    case .configureSDK:
      let credentials = state.credentials
      let effect = Effect<Settings.Action, Never>.task {[state] in
        if state.canConfigureSDK {
          var configuration = VitalClient.Configuration()
          configuration.logsEnable = true

          if case .local = state.credentials.environment {
            configuration.localDebug = true
          }

          switch state.credentials.authMode {
          case .apiKey:
            await VitalClient.configure(
              apiKey: state.credentials.apiKey,
              environment: state.credentials.environment,
              configuration: configuration
            )

            let userId = UUID(uuidString: state.credentials.userId)!
            await VitalClient.setUserId(userId)

          case .userJWTDemo:
            let controlPlane = VitalClient.controlPlane(apiKey: credentials.apiKey, environment: credentials.environment)
            let tokenCreationResponse = try await controlPlane.createSignInToken(userId: UUID(uuidString: credentials.userId)!)

            try await VitalClient.signIn(
              withRawToken: tokenCreationResponse.signInToken,
              configuration: configuration
            )
          }
          

          await VitalHealthKitClient.configure(
            .init(
              backgroundDeliveryEnabled: true,
              numberOfDaysToBackFill: 365,
              logsEnabled: true
            )
          )
        }

        return .didConfigureSDK
      } catch: { error in
        let alert = AlertState<Settings.Action> {
          TextState("SDK Error")
        } actions: {
          ButtonState(role: ButtonStateRole.cancel, action: .send(nil)) {
            TextState("OK")
          }
        } message: {
          TextState("\(String(describing: error))")
        }
        return .binding(BindingAction.set(\.$alert, alert))
      }

      return effect
        .receive(on: DispatchQueue.main)
        .eraseToEffect()

    case .resetSDK:
      return .task {
        await VitalClient.shared.signOut()
        return .didResetSDK
      }

    case .didResetSDK, .didConfigureSDK:
      return .none
      
    case .start:
      if
        let data = UserDefaults.standard.data(forKey: "credentials"),
        let decoded = try? JSONDecoder().decode(Settings.Credentials.self, from: data)
      {
        state.credentials = decoded
      }

      // NOTE: We use automaticConfiguration(), so we need not repeatedly configure the SDK
      // every time the app (re-)launches.
      return .none
  }
}
  .binding()

extension Settings {
  struct RootView: View {
    
    let store: Store<State, Action>
    @FocusState private var activeKeyboard: Bool
    @SwiftUI.State private var enablePersistentLogging: Bool = VitalPersistentLogger.isEnabled

    static let allEnviornments: [VitalCore.Environment] = [
      .sandbox(.eu),
      .sandbox(.us),
      .production(.eu),
      .production(.us),
      .dev(.eu),
      .dev(.us),
      .local(.eu),
      .local(.us),
    ]
    
    var body: some View {
      WithViewStore(self.store) { viewStore in
        NavigationView {
          Form {
            Section("SDK State") {
              HStack {
                Text("Status")
                Spacer()
                Text(viewStore.sdkIsConfigured ? "Configured" : "nil")
                  .foregroundColor(Color.secondary)
              }

              HStack {
                Text("User ID")
                Spacer()
                Text(viewStore.sdkUserId ?? "nil")
                  .lineLimit(1)
                  .foregroundColor(Color.secondary)
              }
            }
            
            Section {
              VStack(alignment: .leading) {
                HStack {
                  Text("API Key")
                    .fontWeight(.semibold)
                    .font(.footnote)
                  Spacer()
                  InputValidityIndicator(isValid: viewStore.hasValidAPIKey)
                }

                TextField("API Key", text: viewStore.binding(\.$credentials.apiKey))
                  .foregroundColor(Color.secondary)
                  .disableAutocorrection(true)
                  .focused($activeKeyboard)
                  .disabled(viewStore.sdkIsConfigured)
              }

              VStack(alignment: .leading) {
                HStack {
                  Text("User ID (UUID-4)")
                    .fontWeight(.semibold)
                    .font(.footnote)
                  Spacer()
                  InputValidityIndicator(isValid: viewStore.hasValidUserId)
                }

                TextField("User ID (UUID-4)", text: viewStore.binding(\.$credentials.userId))
                  .foregroundColor(Color.secondary)
                  .disableAutocorrection(true)
                  .focused($activeKeyboard)
                  .disabled(viewStore.sdkIsConfigured)
              }

              Picker("Environment", selection: viewStore.binding(\.$credentials.environment)) {
                ForEach(Self.allEnviornments, id: \.self) { environment in
                  Text(String(describing: environment)).tag(environment)
                }
              }
              .disabled(viewStore.sdkIsConfigured)

              Picker("Auth", selection: viewStore.binding(\.$credentials.authMode)) {
                Text("API Key").tag(AuthMode.apiKey)
                Text("Sign-In Token Demo").tag(AuthMode.userJWTDemo)
              }
              .disabled(viewStore.sdkIsConfigured)
            } header: {
              Text("Configuration")
            } footer: {
              configurationFooter(viewStore)
            }

            Section("Actions") {
              Button("Generate User ID", action: {
                self.activeKeyboard = false
                viewStore.send(.genetareUserId)
              })
              .disabled(viewStore.canGenerateUserId == false)

              Button(viewStore.credentials.authMode.configureActionTitle, action: {
                self.activeKeyboard = false
                viewStore.send(.configureSDK)
              })
              .disabled(viewStore.canConfigureSDK == false)

              Button("Reset SDK", action: {
                self.activeKeyboard = false
                viewStore.send(.resetSDK)
              })
              .disabled(viewStore.sdkIsConfigured == false)

              if viewStore.credentials.authMode == .userJWTDemo {
                Button("Force Token Refresh", action: {
                  Task {
                    try await VitalClient.forceRefreshToken()
                  }
                })
                .disabled(viewStore.sdkIsConfigured == false)
              }
            }

            Section("Logging") {
              Toggle(
                "Persistent Logging",
                isOn: $enablePersistentLogging
              )

              Button("Share Persistent Logs") {
                VitalHealthKitClient.createAndShareLogArchive()
              }

              Button("Reset Persistent Log") {
                try! VitalHealthKitClient.clearLogs()
              }
              .disabled(!enablePersistentLogging)
            }
          }
          .onAppear {
            UIScrollView.appearance().keyboardDismissMode = .onDrag
          }
          .onChange(of: enablePersistentLogging) { newValue in
            VitalPersistentLogger.isEnabled = newValue
          }
          .alert(store.scope(state: \.alert), dismiss: .dismissAlert)
          .navigationBarTitle(Text("Settings"), displayMode: .large)
        }
      }
    }

    @ViewBuilder func configurationFooter(_ viewStore: ViewStore<State, Action>) -> some View {
      if viewStore.sdkIsConfigured {
        Text("The configuration is locked. Reset SDK to unlock.")
          .font(.footnote)
      }

      if viewStore.credentials.authMode == .userJWTDemo {
        HStack(alignment: .firstTextBaseline) {
          Image(systemName: "info.circle")
          Text("""
          API Key should be a server-side secret when you use Sign-In Token.
          The demo app uses it to generate Sign-In Token only for illustration.
          """)
        }
      }
    }
  }
}


extension Settings {
  struct InputValidityIndicator: View {
    let isValid: Bool
    var body: some View {
      if isValid {
        Image(systemName: "checkmark.circle.fill")
          .foregroundColor(Color.green)
          .imageScale(.small)
      } else {
        Image(systemName: "exclamationmark.triangle.fill")
          .foregroundColor(Color.red)
          .imageScale(.small)
      }
    }
  }
}
