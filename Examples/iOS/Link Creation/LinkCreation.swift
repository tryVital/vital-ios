import SwiftUI
import VitalDevices
import VitalCore
import ComposableArchitecture
import Combine
import BetterSafariView

enum LinkCreation {}

extension TimeSeriesDataPoint: Identifiable {}
extension BloodPressureDataPoint: Identifiable {}

extension LinkCreation {
  
  struct State: Equatable {
    enum Status {
      case generatingLink
      case initial
      case fetchingData
    }
    
    var link: URL?
    var status: Status = .initial
    var glucosePoints: [TimeSeriesDataPoint] = []
    var bloodPressurePoints: [BloodPressureDataPoint] = []
    var showingWebAuthentication: Bool = false
    
    var isTimerActive: Bool = false
    
    var isGeneratingLink: Bool {
      switch status {
        case .generatingLink:
          return true
        default:
          return false
      }
    }
    
    var isFetchingData: Bool {
      switch status {
        case .fetchingData:
          return true
        default:
          return false
      }
    }
    
    var generateLinkTitle: String {
      switch status {
        case .generatingLink:
          return "Loading..."
        default:
          return "Generate link"
      }
    }
    
    var fetchDataTitle: String {
      switch status {
        case .fetchingData:
          return "Loading..."
        default:
          return "Fetch Data"
      }
    }
  }
  
  enum Action: Equatable {
    case generateLink
    case successGeneratedLink(URL)
    case failedGeneratedLink(String)
    
    case callback(URL)
    case successFetchingData([TimeSeriesDataPoint], [BloodPressureDataPoint])
    case failedFetchingData(String)
    case toggleWebView(Bool)
    case fetchData
    
    case startTimer
  }
  
  class Environment {
    init() {}
  }
}

let linkCreationReducer = Reducer<LinkCreation.State, LinkCreation.Action, LinkCreation.Environment> { state, action, _ in
  struct TimerId: Hashable {}

  switch action {
      
    case let .toggleWebView(value):
      state.showingWebAuthentication = value
      
      if value == false {
        state.status = .initial
      }
      
      return .none
      
    case .startTimer:
      if VitalNetworkClient.isSetup == false {
        return .none
      }
      
      state.isTimerActive.toggle()
      
      let effect = Effect.timer(
        id: TimerId(),
        every: 5,
        tolerance: .zero,
        on: DispatchQueue.main
      )
      .map { _ in LinkCreation.Action.fetchData }
      
      return state.isTimerActive ? effect : Effect.cancel(id: TimerId())
      
    case let .callback(url):
      /// do something with the URL
      state.status = .initial
      state.link = nil
      
      return .init(value: .toggleWebView(false))
      
    case .fetchData:
      if VitalNetworkClient.isSetup == false {
        return .none
      }
      
      state.status = .fetchingData
      
      let effect = Effect<LinkCreation.Action, Error>.task {
        let calendar = Calendar.current
        let aWeekAgo = calendar.date(byAdding: .weekOfYear, value: -1, to: Date())!
        
        let glucosePoints = try await VitalNetworkClient.shared.timeSeries.get(resource: .glucose, startDate: aWeekAgo)
        let bloodPressurePoints = try await VitalNetworkClient.shared.timeSeries.getBloodPressure(startDate: aWeekAgo)

        return .successFetchingData(glucosePoints, bloodPressurePoints)
      }.catch { error in
        return Just(LinkCreation.Action.failedFetchingData(error.localizedDescription))
      }
        .receive(on: DispatchQueue.main)
        .eraseToEffect()
    
      return effect
      
    case let .successFetchingData(glucosePoints, bloodPressurePoints):
      
      state.status = .initial
      state.glucosePoints = glucosePoints
      state.bloodPressurePoints = bloodPressurePoints
      
      return .none
      
    case let .failedFetchingData(points):
      state.status = .initial
      return .none
      
    case let .failedGeneratedLink(error):
      state.status = .initial
      state.bloodPressurePoints = []
      state.glucosePoints = []
      
      return .none
      
    case let .successGeneratedLink(url):
      state.bloodPressurePoints = []
      state.glucosePoints = []
      
      state.link = url
      return .init(value: .toggleWebView(true))
      
    case .generateLink:
      if VitalNetworkClient.isSetup == false {
        return .none
      }
      
      state.status = .generatingLink
      state.bloodPressurePoints = []
      state.glucosePoints = []
      
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
    
    @SwiftUI.State private var isPresenting = false
    
    var body: some View {
      WithViewStore(self.store) { viewStore in
        NavigationView {
          Form {
            Section("Glucose") {
              if viewStore.state.glucosePoints.isEmpty  {
                Text("No data")
              } else {
                ForEach(viewStore.glucosePoints) { (point: TimeSeriesDataPoint) in
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
            }
            
            Section("Blood Pressure") {
              if viewStore.state.bloodPressurePoints.isEmpty  {
                Text("No data")
              } else {
                ForEach(viewStore.state.bloodPressurePoints) { (point: BloodPressureDataPoint) in
                  HStack {
                    VStack(alignment: .leading, spacing: 5) {
                      HStack {
                        Text("\(Int(point.systolic))")
                          .font(.title)
                          .fontWeight(.medium)
                        Text("\(point.unit)")
                          .foregroundColor(.gray)
                          .font(.footnote)
                      }
                      
                      HStack {
                        Text("\(Int(point.diastolic))")
                          .font(.title)
                          .fontWeight(.medium)
                        Text("\(point.unit)")
                          .foregroundColor(.gray)
                          .font(.footnote)
                      }
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
            }
            Section(content: {
              EmptyView()
            }, footer: {
                Button(viewStore.generateLinkTitle, action: {
                  viewStore.send(.generateLink)
                })
                .buttonStyle(LoadingButtonStyle(isLoading: viewStore.isGeneratingLink))
                .cornerRadius(5.0)
                .padding([.bottom], 20)
            })
            .onReceive(viewStore.publisher.showingWebAuthentication, perform: { value in
              isPresenting = value
            })
            .fullScreenCover(isPresented: $isPresenting, content: {
              if let url = viewStore.link {
                ModalView(url: url)
                  .onDisappear(perform: {
                    viewStore.send(.toggleWebView(false))
                  })
              }
            })
          }
          .navigationBarTitle(Text("Link"), displayMode: .large)
        }
      }
    }
  }
}

struct ModalView: View {
  @SwiftUI.Environment(\.presentationMode) var presentation
  
  let url: URL
  
  var body: some View {
    SafariView(
      url: url,
      configuration: SafariView.Configuration(
        entersReaderIfAvailable: false,
        barCollapsingEnabled: true
      )
    )
    .preferredControlAccentColor(.accentColor)
    .dismissButtonStyle(.done)
  }
}
