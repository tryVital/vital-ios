@_spi(VitalSDKInternals) import VitalCore
import Foundation
import UIKit
import Combine

public struct SyncProgress: Codable {
  public var backfillTypes: [BackfillType: Resource] = [:]

  public init() {}

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.backfillTypes = Dictionary(
      uniqueKeysWithValues: (try container.decode([String: Resource].self, forKey: .backfillTypes))
        .map { (BackfillType(rawValue: $0.key), $0.value) }
    )
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(
      Dictionary(uniqueKeysWithValues: backfillTypes.map { ($0.key.rawValue, $0.value) }),
      forKey: .backfillTypes
    )
  }

  public enum CodingKeys: String, CodingKey {
    case backfillTypes
  }

  public enum SystemEventType: Int, Codable {
    case healthKitCalloutBackground = 0
    case healthKitCalloutForeground = 1
    case backgroundProcessingTask = 2
  }

  public struct Event<EventType: Equatable & Codable>: Codable, Identifiable {
    public let timestamp: Date
    public let type: EventType
    public var count: Int = 1

    public var id: Date { timestamp }

    public init(timestamp: Date, type: EventType) {
      self.timestamp = timestamp
      self.type = type
    }
  }

  public enum SyncStatus: Int, Codable {
    case deprioritized = 0
    case started = 1
    case readChunk = 2
    case uploadedChunk = 3
    case noData = 6
    case error = 7
    case cancelled = 4
    case completed = 5
    case revalidatingSyncState = 8
    case timedOut = 9

    public var isInProgress: Bool {
      switch self {
      case .deprioritized, .started, .readChunk, .uploadedChunk, .revalidatingSyncState:
        return true
      case .completed, .noData, .cancelled, .error, .timedOut:
        return false
      }
    }
  }

  public struct Sync: Codable, Identifiable {
    public let start: Date
    public var end: Date?
    public var tags: Set<SyncContextTag>
    public private(set) var statuses: [Event<SyncStatus>]

    public var lastStatus: SyncStatus {
      statuses.last!.type
    }

    public var id: Date { start }

    public init(start: Date, status: SyncStatus, tags: Set<SyncContextTag>) {
      self.start = start
      self.statuses = [Event(timestamp: start, type: status)]
      self.tags = tags
    }

    public mutating func append(_ status: SyncStatus, at timestamp: Date = Date()) {
      statuses.append(Event(timestamp: timestamp, type: status))
    }

    public mutating func pruneDeprioritizedStatus(afterFirst count: Int) {
      let indicesToDelete = IndexSet(
        statuses.dropFirst(count).indices.filter { statuses[$0].type == .deprioritized }
      )

      guard !indicesToDelete.isEmpty else { return }
      statuses.remove(atOffsets: indicesToDelete)
    }
  }

  public struct SyncID {
    public let resource: VitalResource
    public let start: Date
    public var tags: Set<SyncContextTag>

    public init(resource: VitalResource, tags: Set<SyncContextTag>) {
      self.resource = resource
      self.tags = tags
      self.start = Date()
    }
  }

  public struct Resource: Codable {
    public var syncs: [Sync] = []
    public var systemEvents: [Event<SystemEventType>] = []
    public var uploadedChunks: Int = 0
    public var firstAsked: Date? = nil

    public var latestSync: Sync? {
      syncs.last
    }

    mutating func with(_ action: (inout Self) -> Void) {
      action(&self)
    }
  }
}

final class SyncProgressStore {
  private let state = CurrentValueSubject<SyncProgress, Never>(SyncProgress())
  private var hasChanges = false
  private let lock = NSLock()

  static let shared = SyncProgressStore()

  private var cancellables: Set<AnyCancellable> = []
  private var multicaster: AnyPublisher<SyncProgress, Never>!

  init() {
    state.value = VitalGistStorage.shared.get(SyncProgressGistKey.self) ?? SyncProgress()

    NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)
      .sink { [weak self] _ in self?.flush() }
      .store(in: &cancellables)

    Timer.publish(every: 10.0, on: RunLoop.main, in: .default)
      .autoconnect()
      .sink { [weak self] _ in self?.flush() }
      .store(in: &cancellables)
  }

  func get() -> SyncProgress {
    lock.withLock { state.value }
  }

  func publisher() -> some Publisher<SyncProgress, Never> {
    // Force all values to be received asynchronously.
    // This eliminates the possibility of deadlocks during subscriber callouts.
    state.receive(on: RunLoop.main)
  }

  func flush() {
    lock.withLock {
      if hasChanges {
        try? VitalGistStorage.shared.set(state.value, for: SyncProgressGistKey.self)
        hasChanges = false
      }
    }
  }

  func clear() {
    lock.withLock {
      state.value = SyncProgress()
      try? VitalGistStorage.shared.set(Optional<SyncProgress>.none, for: SyncProgressGistKey.self)
    }
  }

  func recordSync(_ id: SyncProgress.SyncID, _ status: SyncProgress.SyncStatus) {
    mutate(CollectionOfOne(id.resource.resourceToBackfillType())) {
      let now = Date()

      let latestSync = $0.syncs.last
      let appendsToLatestSync = (
        // Shares the same start timestamp
        latestSync?.start == id.start

        // OR last status is deprioritized
        || status == .deprioritized && latestSync?.lastStatus == .deprioritized
      )

      if appendsToLatestSync {
        let index = $0.syncs.count - 1
        $0.syncs[index].append(status, at: now)
        $0.syncs[index].tags = id.tags

        switch status {
        case .completed, .error, .cancelled, .noData:
          $0.syncs[index].end = now

        case .deprioritized:
          // Drop any deprioritized events beyond the first 10
          $0.syncs[index].pruneDeprioritizedStatus(afterFirst: 10)

        default:
          break
        }

      } else {
        if $0.syncs.count > 50 {
          $0.syncs.removeFirst()
        }

        $0.syncs.append(
          SyncProgress.Sync(start: id.start, status: status, tags: id.tags)
        )
      }
    }
  }

  func recordSystem(_ resources: some Sequence<RemappedVitalResource>, _ eventType: SyncProgress.SystemEventType) {
    mutate(resources.map { $0.wrapped.resourceToBackfillType() }) {
      let now = Date()

      // Capture this new event if the event type is different or 2 seconds have elapsed.
      let appendsCount = $0.systemEvents.last.map { $0.type == eventType && now.timeIntervalSince($0.timestamp) <= 5.0 } ?? false

      if appendsCount {
        $0.systemEvents[$0.systemEvents.endIndex - 1].count += 1

      } else {
        if $0.systemEvents.count > 25 {
          $0.systemEvents.removeFirst()
        }

        $0.systemEvents.append(
          SyncProgress.Event(timestamp: now, type: eventType)
        )
      }
    }
  }

  private func mutate(_ backfillTypes: some Sequence<BackfillType>, action: (inout SyncProgress.Resource) -> Void) {
    lock.withLock {
      var copy = state.value
      for backfillType in backfillTypes {
        copy.backfillTypes[backfillType, default: SyncProgress.Resource()]
          .with(action)
      }

      state.value = copy
      hasChanges = true
    }
  }
}

enum SyncProgressGistKey: GistKey {
  typealias T = SyncProgress

  static var identifier: String = "vital_healthkit_progress"
}
