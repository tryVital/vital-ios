@_spi(VitalSDKInternals) import VitalCore
import Foundation
import UIKit
import Combine

public struct SyncProgress: Codable {
  public var resources: [VitalResource: Resource] = [:]

  public init() {}

  public enum SystemEventType: Int, Codable {
    case healthKitCalloutBackground = 0
    case healthKitCalloutForeground = 1
  }

  public struct Event<EventType: Equatable & Codable>: Codable, Identifiable {
    public let timestamp: Date
    public let type: EventType

    public var id: Date { timestamp }
  }

  public enum SyncStatus: Int, Codable {
    case deprioritized = 0
    case started = 1
    case readChunk = 2
    case uploadedChunk = 3
    case noData = 6
    case timeout = 4
    case completed = 5

    public var isInProgress: Bool {
      switch self {
      case .deprioritized, .started, .readChunk, .uploadedChunk:
        return true
      case .completed, .noData, .timeout:
        return false
      }
    }
  }

  public struct Sync: Codable, Identifiable {
    public let start: Date
    public var end: Date?
    public var trigger: SyncTrigger
    public private(set) var statuses: [Event<SyncStatus>]

    public var lastStatus: SyncStatus {
      statuses.last!.type
    }

    public var id: Date { start }

    public init(start: Date, status: SyncStatus, trigger: SyncTrigger) {
      self.start = start
      self.statuses = [Event(timestamp: start, type: status)]
      self.trigger = trigger
    }

    public mutating func append(_ status: SyncStatus, at timestamp: Date = Date()) {
      statuses.append(Event(timestamp: timestamp, type: status))
    }
  }

  public struct SyncID {
    public let rawValue: Date
    public let trigger: SyncTrigger

    public init(trigger: SyncTrigger) {
      self.rawValue = Date()
      self.trigger = trigger
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
  private var state: SyncProgress {
    didSet { hasChanges = true }
  }
  private var hasChanges = false
  private let lock = NSLock()
  private let didChange = PassthroughSubject<Void, Never>()

  static let shared = SyncProgressStore()

  private var cancellables: Set<AnyCancellable> = []
  private var multicaster: AnyPublisher<SyncProgress, Never>!

  init() {
    state = VitalGistStorage.shared.get(SyncProgressGistKey.self) ?? SyncProgress()

    multicaster = didChange.prepend(())
      .map { self.get() }
      .buffer(size: 1, prefetch: .byRequest, whenFull: .dropOldest)
      .share()
      .eraseToAnyPublisher()

    NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)
      .sink { [weak self] _ in self?.flush() }
      .store(in: &cancellables)

    Timer.publish(every: 10.0, on: RunLoop.main, in: .default)
      .autoconnect()
      .sink { [weak self] _ in self?.flush() }
      .store(in: &cancellables)
  }

  func get() -> SyncProgress {
    lock.withLock { state }
  }

  func publisher() -> some Publisher<SyncProgress, Never> {
    multicaster
  }

  func flush() {
    lock.withLock {
      if hasChanges {
        try? VitalGistStorage.shared.set(state, for: SyncProgressGistKey.self)
        hasChanges = false
      }
    }
  }

  func clear() {
    lock.withLock {
      state = SyncProgress()
      try? VitalGistStorage.shared.set(Optional<SyncProgress>.none, for: SyncProgressGistKey.self)
    }

    didChange.send(())
  }

  func recordSync(_ resource: RemappedVitalResource, _ status: SyncProgress.SyncStatus, for id: SyncProgress.SyncID) {
    mutate(CollectionOfOne(resource)) {
      let now = Date()

      let latestSync = $0.syncs.last
      let appendsToLatestSync = (
        // Shares the same start timestamp
        latestSync?.start == id.rawValue

        // OR last status is deprioritized
        || status == .deprioritized && latestSync?.lastStatus == .deprioritized
      )

      if appendsToLatestSync {
        let index = $0.syncs.count - 1
        $0.syncs[index].append(status, at: now)

        switch status {
        case .completed, .timeout, .noData:
          $0.syncs[index].end = now

        default:
          break
        }

      } else {
        if $0.syncs.count > 50 {
          $0.syncs.removeFirst()
        }

        $0.syncs.append(
          SyncProgress.Sync(start: id.rawValue, status: status, trigger: id.trigger)
        )
      }
    }
  }

  func recordSystem(_ resources: some Sequence<RemappedVitalResource>, _ eventType: SyncProgress.SystemEventType) {
    mutate(resources) {
      let now = Date()

      // Capture this new event if the event type is different or 2 seconds have elapsed.
      let shouldCapture = $0.systemEvents.first.map { $0.type != eventType || now.timeIntervalSince($0.timestamp) >= 2.0 } ?? true
      guard shouldCapture else { return }

      if $0.systemEvents.count > 25 {
        $0.systemEvents.removeFirst()
      }

      $0.systemEvents.append(
        SyncProgress.Event(timestamp: now, type: eventType)
      )
    }
  }

  private func mutate(_ resources: some Sequence<RemappedVitalResource>, action: (inout SyncProgress.Resource) -> Void) {
    lock.withLock {
      for resource in resources {
        state.resources[resource.wrapped, default: SyncProgress.Resource()]
          .with(action)
      }
    }

    didChange.send(())
  }
}

enum SyncProgressGistKey: GistKey {
  typealias T = SyncProgress

  static var identifier: String = "vital_healthkit_progress"
}
