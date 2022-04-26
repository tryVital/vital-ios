import SwiftUI
import VitalDevices
import VitalCore
import ComposableArchitecture
import Combine

enum LinkCreation {}

extension TimeSeriesDataPoint: Identifiable {}

extension LinkCreation {
  
  struct State: Equatable {
    enum Status {
      case loading
      case successLink
      case initial
    }
    
    var link: URL?
    var status: Status = .initial
    var dataPoints: [TimeSeriesDataPoint] = []
    
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
    case failedGeneratedLink(String)
    
    case callback(URL)
    case successFetchingGlucose([TimeSeriesDataPoint])
    case failedFetchingGlucose(String)
  }
  
  class Environment {
    init() {}
  }
}

let linkCreationReducer = Reducer<LinkCreation.State, LinkCreation.Action, LinkCreation.Environment> { state, action, _ in
  
  switch action {
      
    case let .callback(url):
      state.status = .initial
      state.link = nil
      
      let effect = Effect<[TimeSeriesDataPoint], Error>.task {
        let calendar = Calendar.current
        let aWeekAgo = calendar.date(byAdding: .weekOfYear, value: -1, to: Date())!
        
        let timeSeries = try await VitalNetworkClient.shared.timeSeries.get(resource: .glucose, provider: .appleHealthKit, startDate: aWeekAgo)
        return timeSeries
        
      }.map { (points: [TimeSeriesDataPoint]) -> LinkCreation.Action in
        return .successFetchingGlucose(points)
      }.catch { error in
        return Just(LinkCreation.Action.failedFetchingGlucose(error.localizedDescription))
      }
        .receive(on: DispatchQueue.main)
        .eraseToEffect()
      
      return effect
      
    case let .successFetchingGlucose(points):
      
      state.dataPoints = points
      return .none
      
    case let .failedFetchingGlucose(points):
      return .none
      
    case let .failedGeneratedLink(error):
      state.status = .initial
      return .none
      
    case let .successGeneratedLink(url):
      state.status = .successLink
      state.link = url
      return .none
      
    case .generateLink:
      state.status = .loading
      
      let effect = Effect<URL, Error>.task {
        let url = try await VitalNetworkClient.shared.link.createProviderLink(redirectURL: "vitalExample://")
        return url
        
      }.map { (url: URL) -> LinkCreation.Action in
        return .successGeneratedLink(url)
      }.catch { error in
        return Just(LinkCreation.Action.failedGeneratedLink(error.localizedDescription))
      }
        .receive(on: DispatchQueue.main)
        .eraseToEffect()
      
      return effect
  }
}

extension LinkCreation {
  struct RootView: View {
    
    let store: Store<State, Action>
    
    var body: some View {
      WithViewStore(self.store) { viewStore in
        NavigationView {
          Form {
            Section(content: {
              
              if viewStore.dataPoints.isEmpty {
                Text("No data")
              } else {
                ForEach(viewStore.dataPoints) { (point: TimeSeriesDataPoint) in
                  HStack {
                    VStack {
                      Text("\(Int(point.value))")
                        .font(.title)
                        .fontWeight(.medium)
                      
                      Text("\(point.unit ?? "")")
                        .font(.footnote)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing) {
                      Text("\(point.timestamp.getDay())")
                        .font(.body)
                      Text("\(point.timestamp.getDate())")
                        .font(.body)
                    }
                  }
                  .padding([.horizontal], 10)
                }
              }
              
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

