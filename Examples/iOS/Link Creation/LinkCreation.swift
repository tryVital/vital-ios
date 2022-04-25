import SwiftUI
import VitalHealthKit
import VitalDevices
import VitalCore
import ComposableArchitecture
import NukeUI
import Combine

enum LinkCreation {}

extension LinkCreation {
  
  struct State: Equatable {
    enum Status {
      case loading
      case successLink
      case initial
    }
    
    var link: URL?
    var status: Status = .initial
    
    var isLoading: Bool {
      switch status {
        case .loading:
          return true
        default:
          return false
      }
    }
    
    var title: String {
      switch status {
        case .loading:
          return "Loading..."
        case .initial:
          return "Generate link"
        case .successLink:
          return "Open Link"
      }
    }
  }
  
  enum Action: Equatable {
    case generateLink
    case successGeneratedLink(URL)
    case failureGeneratedLink(String)
  }
  
  class Environment {
    init() {}
  }
}

private let reducer = Reducer<LinkCreation.State, LinkCreation.Action, LinkCreation.Environment> { state, action, _ in
  
  switch action {
      
    case let .failureGeneratedLink(error):
      state.status = .initial
      return .none
      
    case let .successGeneratedLink(url):
      state.status = .successLink
      state.link = url
      
      return .none
      
    case .generateLink:
      state.status = .loading
      
      let effect = Effect<URL, Error>.task {
        let url = try await VitalNetworkClient.shared.link.createProviderLink(
          provider: .iHealth,
          redirectURL: "vitalExample.io"
        )
        
        return url
      }
      
      let outcome: Effect<LinkCreation.Action, Never> = effect.map { (url: URL) -> LinkCreation.Action in
        return .successGeneratedLink(url)
      }
        .catch { error in
          return Just(LinkCreation.Action.failureGeneratedLink(error.localizedDescription))
        }
        .receive(on: DispatchQueue.main)
        .eraseToEffect()
      
      return outcome
  }
}


let linkCreationStore = Store(
  initialState: LinkCreation.State(),
  reducer: reducer,
  environment: LinkCreation.Environment()
)

extension LinkCreation {
  struct RootView: View {
    
    let store: Store<State, Action>
    @FocusState private var activeKeyboard: Bool
    
    
    var body: some View {
      WithViewStore(self.store) { viewStore in
        NavigationView {
          Form {
            Section(content: {
              Text("No data")
            }, footer: {
              Button(viewStore.title, action: {
                
                if let url = viewStore.state.link {
                  UIApplication.shared.open(url, options: [:])
                } else {
                  viewStore.send(.generateLink)
                }
              })
              .buttonStyle(LoadingButtonStyle(isLoading: viewStore.isLoading))
              .cornerRadius(5.0)
              .padding([.bottom], 20)
            })
          }
          
          .navigationBarTitle(Text("Link"), displayMode: .large)
        }
      }
    }
  }
}
  
