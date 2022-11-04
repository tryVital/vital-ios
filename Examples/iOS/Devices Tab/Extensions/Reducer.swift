import ComposableArchitecture
import Foundation

extension Reducer {
  public func presents<LocalState, LocalAction, LocalEnvironment>(
    _ localReducer: Reducer<LocalState, LocalAction, LocalEnvironment>,
    cancelEffectsOnDismiss: Bool,
    state toLocalState: WritableKeyPath<State, LocalState?>,
    action toLocalAction: CasePath<Action, LocalAction>,
    environment toLocalEnvironment: @escaping (Environment) -> LocalEnvironment
  ) -> Self {
    let id = UUID()
    return Self { state, action, environment in
      let hadLocalState = state[keyPath: toLocalState] != nil
      let localEffects = localReducer
        .optional()
        .pullback(state: toLocalState, action: toLocalAction, environment: toLocalEnvironment)
        .run(&state, action, environment)
        .cancellable(id: id)
      let globalEffects = self.run(&state, action, environment)
      let hasLocalState = state[keyPath: toLocalState] != nil
      return .merge(
        localEffects,
        globalEffects,
        cancelEffectsOnDismiss && hadLocalState && !hasLocalState ? .cancel(id: id) : .none
      )
    }
  }
}
