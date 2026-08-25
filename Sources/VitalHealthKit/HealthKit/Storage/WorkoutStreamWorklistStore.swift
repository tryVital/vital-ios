import Foundation
@_spi(VitalSDKInternals) import VitalCore

actor WorkoutStreamWorklistStore {
  static let shared = WorkoutStreamWorklistStore()

  private let storage: VitalGistStorage

  init(storage: VitalGistStorage = .shared) {
    self.storage = storage
  }

  func enqueue(_ workouts: [WorkoutPatch.Workout]) {
    let items = workouts.compactMap(WorkoutStreamWorkItem.init)
    guard items.isEmpty == false else {
      return
    }

    var state = loadState()

    for item in items {
      if let index = state.items.firstIndex(where: { $0.id == item.id }) {
        state.items[index] = item
      } else {
        state.items.append(item)
      }
    }

    saveState(state)
  }

  func snapshot() -> [WorkoutStreamWorkItem] {
    loadState().items
  }

  func writeDiagnosticSnapshot(to url: URL) throws {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

    try FileManager.default.createDirectory(
      at: url.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    try encoder.encode(loadState()).write(to: url, options: .atomic)
  }

  func remove(_ ids: some Sequence<UUID>) {
    let idSet = Set(ids)
    guard idSet.isEmpty == false else {
      return
    }

    var state = loadState()
    state.items.removeAll { idSet.contains($0.id) }
    saveState(state)
  }

  func complete(_ ids: [UUID]) {
    remove(ids)
  }

  private func loadState() -> WorkoutStreamWorklistState {
    storage.get(WorkoutStreamWorklistGistKey.self) ?? WorkoutStreamWorklistState()
  }

  private func saveState(_ state: WorkoutStreamWorklistState) {
    try? storage.set(state.items.isEmpty ? nil : state, for: WorkoutStreamWorklistGistKey.self)
  }
}

struct WorkoutStreamWorkItem: Codable, Equatable, Sendable {
  let id: UUID
  let startDate: Date
  let endDate: Date
  let sourceBundle: String
  let productType: String?
  let sport: String
  let metadata: [String: String]

  init(
    id: UUID,
    startDate: Date,
    endDate: Date,
    sourceBundle: String,
    productType: String?,
    sport: String,
    metadata: [String: String]
  ) {
    self.id = id
    self.startDate = startDate
    self.endDate = endDate
    self.sourceBundle = sourceBundle
    self.productType = productType
    self.sport = sport
    self.metadata = metadata
  }

  init?(_ workout: WorkoutPatch.Workout) {
    guard let id = workout.id else {
      return nil
    }

    self.init(
      id: id,
      startDate: workout.startDate,
      endDate: workout.endDate,
      sourceBundle: workout.sourceBundle,
      productType: workout.productType,
      sport: workout.sport,
      metadata: workout.metadata
    )
  }
}

private struct WorkoutStreamWorklistState: Codable {
  var items: [WorkoutStreamWorkItem] = []
}

private enum WorkoutStreamWorklistGistKey: GistKey {
  typealias T = WorkoutStreamWorklistState
  static let identifier = "vital_workout_stream_worklist"
}
