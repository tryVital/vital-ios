import HealthKit
import Combine
import os.log
import UIKit
@_spi(VitalSDKInternals) import VitalCore
import BackgroundTasks

let processingTaskIdentifier = "io.tryvital.VitalHealthKit.ProcessingTask"

public enum PermissionStatus: Equatable, Sendable {
  case asked
  case notAsked
}

public enum PermissionOutcome: Equatable, Sendable {
  case success
  case failure(String)
  case healthKitNotAvailable
}

@objc public class VitalHealthKitClient: NSObject {
  public enum ConnectionStatus {
    /// The Health SDK is using `ConnectionPolicy.autoConnect`.
    case autoConnect

    /// There is an active HealthKit connection.
    /// The Health SDK is using `ConnectionPolicy.explicit`.
    case connected

    /// There is an active HealthKit connection, but it is paused due to user ingestion bounds set via the Junction API.
    /// The Health SDK is using `ConnectionPolicy.explicit`.
    case connectionPaused

    /// There is no active HealthKit connection.
    /// The Health SDK is using `ConnectionPolicy.explicit`.
    case disconnected
  }

  public enum Status {
    case failedSyncing(VitalResource, Error?)
    case successSyncing(VitalResource, ProcessedResourceData)
    case nothingToSync(VitalResource)
    case syncing(VitalResource)
    case syncingCompleted
  }

  public static var shared: VitalHealthKitClient {
    clientInitLock.withLock {
      guard let value = client else {
        let newClient = VitalHealthKitClient()
        Self.client = newClient
        Self.bind(newClient, core: VitalClient.shared)
        return newClient
      }

      return value
    }
  }

  private static let clientInitLock = NSLock()
  private static var client: VitalHealthKitClient?

  let storage: VitalHealthKitStorage

  private let store: VitalHealthKitStore
  private let secureStorage: VitalSecureStorage
  private let vitalClient: VitalClientProtocol

  private let _status: PassthroughSubject<Status, Never>
  private var backgroundDeliveryTask: BackgroundDeliveryTask? = nil

  private var cancellables: Set<AnyCancellable> = []

  internal let backgroundDeliveryEnabled: ProtectedBox<Bool> = .init(value: false)
  private let backendSyncStateParkingLot = ParkingLot()
  private let connectDisconnectParkingLot = ParkingLot()

  let configuration: ProtectedBox<Configuration>

  let syncSerializerLock = NSLock()
  var syncSerializer: [RemappedVitalResource: ParkingLot] = [:]

  private var scope = SupervisorScope()

  private var isAutoSyncConfigured: Bool {
    backgroundDeliveryEnabled.value ?? false
  }

  private let _connectionStatusDidChange = PassthroughSubject<Void, Never>()

  @available(*, deprecated, message:"Use `VitalHealthKitClient.shared.syncProgressPublisher`.")
  public var status: AnyPublisher<Status, Never> {
    return _status.eraseToAnyPublisher()
  }

  init(
    configuration: ProtectedBox<Configuration> = .init(),
    store: VitalHealthKitStore = .live,
    storage: VitalHealthKitStorage = .init(storage: .live),
    secureStorage: VitalSecureStorage = .init(keychain: .live),
    vitalClient: VitalClientProtocol = .live
  ) {
    self.store = store
    self.storage = storage
    self.secureStorage = secureStorage
    self.vitalClient = vitalClient
    self.configuration = configuration

    self._status = PassthroughSubject<Status, Never>()

    super.init()
  }

  private static func bind(_ client: VitalHealthKitClient, core: VitalClient) {
    core.registerSignoutTask {
      // NOTE: The connection should not be automatically disconnected upon signout.
      // If we are supporting this behaviour, it must be an opt-in.

      await client.resetAutoSync()

    } completion: {
      client._connectionStatusDidChange.send(())
    }

    client.registerProcessingTaskHandlers()

    AppStateTracker.shared.register { state in
      switch state.status {
      case .background, .launching:
        break

      case .foreground:
        client.scheduleDeprioritizedResourceRetries()

        // Sync profile since most of the content is not observable.
        Task(priority: .high) {
          if try await client.store.authorizationState(.profile).isActive {
            await client.sync(RemappedVitalResource(wrapped: .profile), [.maintenanceTask])
          }
        }

      case .terminating:
        Task(priority: .high) {
          await client.scope.cancel()
          SyncProgressStore.shared.flush()
        }
      }
    }
  }

  /// Only use this method if you are working from Objc.
  /// Please use the async/await configure method when working from Swift.
  @objc public static func configure(
    backgroundDeliveryEnabled: Bool = false,
    numberOfDaysToBackFill: Int = 90,
    logsEnabled: Bool = true
  ) {
    configure(
      .init(
        backgroundDeliveryEnabled: backgroundDeliveryEnabled,
        numberOfDaysToBackFill: numberOfDaysToBackFill,
        logsEnabled: logsEnabled,
        mode: .automatic
      )
    )
  }

  // IMPORTANT: The synchronous `configure(3)` is the preferred version over this async one.
  //
  // The async overload is still kept here for source compatibility, because Swift always ignores
  // the non-async overload sharing the same method signature, even if the async version is
  // deprecated.
  @_disfavoredOverload
  public static func configure(
    _ configuration: Configuration = .init()
  ) async {
    self.shared.setConfiguration(configuration: configuration)
  }

  public static func configure(
    _ configuration: Configuration = .init()
  ) {
    self.shared.setConfiguration(configuration: configuration)
  }

  @objc(automaticConfigurationWithCompletion:)
  public static func automaticConfiguration(completion: (() -> Void)? = nil) {
    do {
      let secureStorage = self.shared.secureStorage
      guard let payload: Configuration = try secureStorage.get(key: health_secureStorageKey) else {
        completion?()
        return
      }

      configure(payload)
      VitalClient.automaticConfiguration(completion: completion)
    } catch let error {
      completion?()
      /// Bailout, there's nothing else to do here.
      /// (But still try to log it if we have a logger around)
      VitalLogger.healthKit.error("Failed to perform automatic configuration: \(error)")
    }
  }

  /// **Synchronously** set the configuration and kick off the side effects.
  ///
  /// - important: This cannot not be `async` due to background observer registration
  /// timing requirement by HealthKit. Instead, spawn async tasks if necessary,
  func setConfiguration(
    configuration: Configuration
  ) {
    do {
      try secureStorage.set(value: configuration, key: health_secureStorageKey)
    }
    catch {
      VitalLogger.healthKit.info("We weren't able to securely store Configuration: \(error)")
    }

    self.configuration.set(value: configuration)
    _connectionStatusDidChange.send(())

    scope.task(priority: .high) {
      // Try to revalidate the LocalSyncState if a revalidation is due.
      // Gracefully ignore the exception thrown by getLocalSyncState().
      _ = try await self.getLocalSyncState()
    }

    if configuration.backgroundDeliveryEnabled && backgroundDeliveryEnabled.value != true {
      backgroundDeliveryEnabled.set(value: true)

      scope.task(priority: .high) {
        let enabled = await self.backgroundDeliveryEnabled.get()
        try await self.checkBackgroundUpdates(isBackgroundEnabled: enabled)
        self.scheduleUnnotifiedResourceRescue()
      }
    }
  }
}

public extension VitalHealthKitClient {
  enum ConnectionPolicy: String, Codable, Sendable {
    case autoConnect
    case explicit
  }

  struct Configuration: Codable {
    public enum DataPushMode: String, Codable {
      case manual
      case automatic

      var isManual: Bool {
        switch self {
        case .manual:
          return true
        case .automatic:
          return false
        }
      }

      var isAutomatic: Bool {
        return isManual == false
      }
    }

    public let backgroundDeliveryEnabled: Bool
    public let numberOfDaysToBackFill: Int
    public let logsEnabled: Bool
    public let mode: DataPushMode
    public let sleepDataAllowlist: AppAllowlist
    public let connectionPolicy: ConnectionPolicy

    public init(
      backgroundDeliveryEnabled: Bool = false,
      numberOfDaysToBackFill: Int = 90,
      logsEnabled: Bool = true,
      mode: DataPushMode = .automatic,
      sleepDataAllowlist: AppAllowlist = .specific(AppIdentifier.defaultsleepDataAllowlist),
      connectionPolicy: ConnectionPolicy = .autoConnect
    ) {
      self.backgroundDeliveryEnabled = backgroundDeliveryEnabled
      self.numberOfDaysToBackFill = min(numberOfDaysToBackFill, 365)
      self.logsEnabled = logsEnabled
      self.mode = mode
      self.sleepDataAllowlist = sleepDataAllowlist
      self.connectionPolicy = connectionPolicy
    }

    public init(from decoder: any Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      self.backgroundDeliveryEnabled = try container.decode(Bool.self, forKey: .backgroundDeliveryEnabled)
      self.numberOfDaysToBackFill = try container.decode(Int.self, forKey: .numberOfDaysToBackFill)
      self.logsEnabled = try container.decode(Bool.self, forKey: .logsEnabled)
      self.mode = try container.decode(DataPushMode.self, forKey: .mode)
      self.sleepDataAllowlist = try container.decodeIfPresent(AppAllowlist.self, forKey: .sleepDataAllowlist)
      ?? .specific(AppIdentifier.defaultsleepDataAllowlist)
      self.connectionPolicy = try container.decodeIfPresent(ConnectionPolicy.self, forKey: .connectionPolicy) ?? .autoConnect
    }
  }

  private struct BackgroundDeliveryTask {
    let task: TaskHandle?
    let resources: Set<RemappedVitalResource>
    let objectTypes: Set<HKObjectType>
    let streamContinuation: AsyncStream<BackgroundDeliveryStage>.Continuation

    func cancel() {
      streamContinuation.finish()
      task?.cancel()
    }
  }
}

extension VitalHealthKitClient {

  @MainActor
  private func checkBackgroundUpdates(isBackgroundEnabled: Bool) async throws {
    guard isBackgroundEnabled else { return }

    let state = try await authorizationState(store: self.store)
    let currentTask = self.backgroundDeliveryTask

    // Reconfigure the task only if the set of resources has changed, or we have not configured it
    // before.
    guard
      state.activeResources != currentTask?.resources
        || state.determinedObjectTypes != currentTask?.objectTypes
    else { return }

    /// If it's already running, cancel it
    currentTask?.cancel()

    let bundles: Set<[HKSampleType]> = Set(
      observedSampleTypes()
        .map { Set($0).intersection(state.determinedObjectTypes).compactMap { $0 as? HKSampleType } }
        .filter { !$0.isEmpty }
    )

    if bundles.isEmpty {
      VitalLogger.healthKit.info("Not observing any type")
    }

    /// Enable background deliveries
    enableBackgroundDelivery(for: bundles.lazy.flatMap { $0 })

    /// Submit BGProcessingTasks
    scope.task { await self.submitProcessingTasks() }

    let stream: AsyncStream<BackgroundDeliveryStage>
    let streamContinuation: AsyncStream<BackgroundDeliveryStage>.Continuation

    if #available(iOS 15.0, *) {
      (stream, streamContinuation) = bundledBackgroundObservers(for: bundles)
    } else {
      (stream, streamContinuation) = backgroundObservers(for: bundles.lazy.flatMap { $0 })
    }

    let payloadListener = scope.task(priority: .userInitiated) {
      var bufferedPayloads: [BackgroundDeliveryPayload] = []
      var timer: Task<Void, Never>?

      defer {
        // If there is any accidential leftover payload, make the completion callback anyway.
        bufferedPayloads.forEach { $0.completion(.completed) }
        timer?.cancel()
      }

      for await stage in stream {
        switch stage {
        case let .received(payload):
          if Task.isCancelled {
            payload.completion(.completed)
            continue
          }

          bufferedPayloads.append(payload)
          VitalLogger.healthKit.info("buffered: \(payload)", source: "BgDelivery")

          if timer == nil {
            timer = Task(priority: .high) {
              // Throttle by 16ms
              // Catch as many parallel HealthKit observer callouts as possible.
              try? await Task.sleep(nanoseconds: NSEC_PER_MSEC * 16)
              streamContinuation.yield(.evaluate)
            }
          }

        case .evaluate:
          timer = nil
          let payloads = bufferedPayloads
          bufferedPayloads = []

          // Task is not cancelled — we must call the HealthKit completion handler irrespective of
          // the sync process outcome. This is to avoid triggering the "strike on 3rd missed delivery"
          // rule of HealthKit background delivery.
          //
          // Since we have fairly frequent delivery anyway, each of which will implicit retry from
          // where the last sync has left off, this unconfigurable exponential backoff retry
          // behaviour adds little to no value in maintaining data freshness.
          //
          // (except for the task cancellation redelivery expectation stated above).
          defer { payloads.forEach { $0.completion(.completed) } }

          let prioritizedResources = Set(payloads.flatMap(\.resources))
            .sorted(by: { $0.wrapped.priority < $1.wrapped.priority })
          let syncsConcurrently = AppStateTracker.shared.state.status == .foreground

          VitalLogger.healthKit.info(
            "dequeued: \(prioritizedResources); will sync \(syncsConcurrently ? "concurrent" : "serially")",
            source: "BgDelivery"
          )

          if syncsConcurrently {
            await withTaskGroup(of: Void.self) { group in
              for resource in prioritizedResources {
                group.addTask {
                  await self.sync(resource, [.healthKit])
                }
              }
            }
          } else {
            for resource in prioritizedResources {
              await self.sync(resource, [.healthKit])
            }
          }
        }
      }
    }

    self.backgroundDeliveryTask = BackgroundDeliveryTask(
      task: payloadListener,
      resources: state.activeResources,
      objectTypes: state.determinedObjectTypes,
      streamContinuation: streamContinuation
    )
  }

  private func enableBackgroundDelivery(for sampleTypes: some Sequence<HKSampleType>) {
    for sampleType in sampleTypes {
      store.enableBackgroundDelivery(sampleType, .immediate) { success, failure in

        guard failure == nil && success else {
          VitalLogger.healthKit.error("failed: \(sampleType.shortenedIdentifier); error = \(String(describing: failure))", source: "EnableBgDelivery")
          return
        }

        VitalLogger.healthKit.info("enabled: \(sampleType.shortenedIdentifier)", source: "EnableBgDelivery")
      }
    }
  }

  // We can only register handlers once, and this must happen before the app finishes launching.
  func registerProcessingTaskHandlers() {
    let scheduler = BGTaskScheduler.shared
    let declaredBgTasks = Set(Bundle.main.object(forInfoDictionaryKey: "BGTaskSchedulerPermittedIdentifiers") as? [String] ?? [])

    if declaredBgTasks.contains(processingTaskIdentifier) {
      scheduler.register(forTaskWithIdentifier: processingTaskIdentifier, using: nil) { task in

        VitalLogger.healthKit.info("begin", source: "ProcessingTask")
        defer { VitalLogger.healthKit.info("ended", source: "ProcessingTask") }

        task.expirationHandler = {
          VitalLogger.healthKit.info("expired", source: "ProcessingTask")
          SyncProgressStore.shared.flush()
          task.setTaskCompleted(success: false)
        }

        self.scope.task(priority: .userInitiated) {
          defer {
            task.setTaskCompleted(success: true)
          }

          guard VitalClient.status.contains(.signedIn) else {
            VitalLogger.healthKit.info("not signed in", source: "ProcessingTask")
            return
          }

          let state = try await authorizationState(store: self.store)

          SyncProgressStore.shared.recordSystem(state.activeResources, .backgroundProcessingTask)

          await withTaskGroup(of: Void.self) { group in
            for resource in state.activeResources {
              group.addTask {
                await self.sync(resource, [.processingTask])
              }
            }
          }

          await self.submitProcessingTasks()
        }
      }
    }
  }

  func submitProcessingTasks() async {
    let scheduler = BGTaskScheduler.shared
    let declaredBgTasks = Set(Bundle.main.object(forInfoDictionaryKey: "BGTaskSchedulerPermittedIdentifiers") as? [String] ?? [])

    if declaredBgTasks.contains(processingTaskIdentifier) {
      let requests = await scheduler.pendingTaskRequests()
      if requests.contains(where: { $0.identifier == processingTaskIdentifier }) {
        VitalLogger.healthKit.info("found existing", source: "ProcessingTask")
        return
      }

      let request: BGProcessingTaskRequest

      if #available(iOS 17.0, *) {
        request = BGHealthResearchTaskRequest(identifier: processingTaskIdentifier)
      } else {
        request = BGProcessingTaskRequest(identifier: processingTaskIdentifier)
      }

      request.requiresExternalPower = true
      request.requiresNetworkConnectivity = true

      // Processing Tasks should be at minimum 6 hours apart
      request.earliestBeginDate = Date().addingTimeInterval(3600 * 6)

      do {
        try scheduler.submit(request)
        VitalLogger.healthKit.info("submitted", source: "ProcessingTask")

      } catch let error {
        VitalLogger.healthKit.info("submission failed: \(error)", source: "ProcessingTask")
      }
    }
  }

  /// HKObserverQuery does not callout at app launch on resources that have no data.
  /// Rescue these resources by checking t
  func scheduleUnnotifiedResourceRescue() {
    scope.task { @MainActor in
      // 1 seconds after app launch or Ask
      try await Task.sleep(nanoseconds: 1 * NSEC_PER_SEC)

      let state = try await authorizationState(store: self.store)
      let connectionStatus = self.connectionStatus
      let connectionActive = connectionStatus == .connected || connectionStatus == .autoConnect

      let knownSyncingResources = SyncProgressReporter.shared.syncingResources()
      let progress = SyncProgressStore.shared.get()

      let unnotifiedResources = state.activeResources.filter { resource in
        guard let resourceProgress = progress.backfillTypes[resource.wrapped.backfillType] else {
          // Doesn't even show up in `SyncProgress.resources`
          return true
        }
        // OR has no sync attempt
        // OR has errored
        guard let lastStatus = resourceProgress.latestSync?.lastStatus else {
          return true
        }

        if lastStatus.isInProgress {
          // The persisted SyncProgress could say in progress. But the resource sync might not be
          // actually active in the current process. e.g. the process was terminated or crashed
          // while the sync was progressing.
          //
          // Cross-check with the in-process syncing resource set from SyncProgressReporter.
          return !knownSyncingResources.contains(resource.wrapped)
        }

        return lastStatus == .error || lastStatus == .cancelled
        || lastStatus == .timedOut || lastStatus == .started || lastStatus == .deprioritized
        || (connectionActive && (lastStatus == .connectionPaused || lastStatus == .connectionDestroyed))
      }

      // Rescue these resources
      await withTaskGroup(of: Void.self) { group in
        for resource in unnotifiedResources {
          await self.sync(resource, [.maintenanceTask])
        }
      }
    }
  }

  @available(iOS 15.0, *)
  private func bundledBackgroundObservers(
    for typesBundle: Set<[HKSampleType]>
  ) -> (AsyncStream<BackgroundDeliveryStage>, AsyncStream<BackgroundDeliveryStage>.Continuation) {

    var _continuation: AsyncStream<BackgroundDeliveryStage>.Continuation!

    let stream = AsyncStream<BackgroundDeliveryStage> { continuation in
      _continuation = continuation

      var queries: [HKObserverQuery] = []

      for typesToObserve in typesBundle {

        let descriptors = typesToObserve.map {
          HKQueryDescriptor(sampleType: $0, predicate: nil)
        }

        let query = HKObserverQuery(queryDescriptors: descriptors) { query, sampleTypes, handler, error in

          guard error == nil else {
            VitalLogger.healthKit.error("observer errored for \(typesToObserve.map(\.shortenedIdentifier)); error = \(String(describing: error)).", source: "HealthKit")
            return
          }

          // Check this after checking error, because sampleTypes is usually nil when error is
          // populated.
          guard let sampleTypes = sampleTypes else {
            VitalLogger.healthKit.error("unexpected callout with no sample type", source: "HealthKit")
            return
          }

          // It appears that the iOS 15+ HKObserverQuery might pass us `HKSampleType`s that is
          // outside the conditions we specified via `descriptors`. Filter out any unsolicited types
          // before proceeding.
          let filteredSampleTypes = sampleTypes.intersection(typesToObserve)

          if filteredSampleTypes.isEmpty {
            handler()
          } else {

            let matches = Set(filteredSampleTypes.flatMap(VitalHealthKitStore.sampleTypeToVitalResource(type:)))
            let remapped = Set(matches.map(VitalHealthKitStore.remapResource))
              .sorted(by: { $0.wrapped.priority < $1.wrapped.priority })

            let payload = BackgroundDeliveryPayload(
              resources: remapped,
              completion: { completion in
                if completion == .completed {
                  handler()
                }
              }
            )
            VitalLogger.healthKit.info("notified: \(payload)", source: "HealthKit")

            continuation.yield(.received(payload))

            SyncProgressStore.shared.recordSystem(
              remapped,
              healthkitCalloutEventType(AppStateTracker.shared.state.status)
            )
          }
        }

        queries.append(query)
        store.execute(query)
      }

      /// If the task is cancelled, make sure we clean up the existing queries
      continuation.onTermination = { @Sendable [queries] _ in
        queries.forEach { query in
          self.store.stop(query)
        }
      }
    }

    return (stream, _continuation)
  }

  private func backgroundObservers(
    for sampleTypes: some Sequence<HKSampleType>
  ) -> (AsyncStream<BackgroundDeliveryStage>, AsyncStream<BackgroundDeliveryStage>.Continuation) {
    var _continuation: AsyncStream<BackgroundDeliveryStage>.Continuation!

    let stream = AsyncStream<BackgroundDeliveryStage> { continuation in
      _continuation = continuation

      var queries: [HKObserverQuery] = []

      for sampleType in sampleTypes {
        let query = HKObserverQuery(sampleType: sampleType, predicate: nil) { query, handler, error in

          guard error == nil else {
            VitalLogger.healthKit.error("observer errored for \(sampleType.shortenedIdentifier); error = \(String(describing: error)).", source: "HealthKit")
            return
          }

          let matches = Set(VitalHealthKitStore.sampleTypeToVitalResource(type: sampleType))
          let remapped = Set(matches.map(VitalHealthKitStore.remapResource))
            .sorted(by: { $0.wrapped.priority < $1.wrapped.priority })

          VitalLogger.healthKit.info("notified: \(remapped.map(\.wrapped.logDescription).joined(separator: ","))", source: "HealthKit")

          let payload = BackgroundDeliveryPayload(
            resources: remapped,
            completion: { completion in
              if completion == .completed {
                handler()
              }
            }
          )
          VitalLogger.healthKit.info("notified: \(payload)", source: "HealthKit")

          continuation.yield(.received(payload))

          SyncProgressStore.shared.recordSystem(
            remapped,
            healthkitCalloutEventType(AppStateTracker.shared.state.status)
          )
        }

        queries.append(query)
        store.execute(query)
      }

      /// If the task is cancelled, make sure we clean up the existing queries
      continuation.onTermination = { @Sendable [queries] _ in
        queries.forEach { query in
          self.store.stop(query)
        }
      }
    }

    return (stream, _continuation)
  }

  public func syncData() {
    scope.task(priority: .high) {
      let state = try await authorizationState(store: self.store)
      self.syncData(for: state.activeResources.map(\.wrapped))
    }
  }

  public func syncData(for resources: [VitalResource]) {
    let remappedResources = Set(resources.map(VitalHealthKitStore.remapResource(_:)))

    scope.task(priority: .high) { @MainActor in
      await withTaskGroup(of: Void.self) { group in
        for resource in remappedResources {
          group.addTask { await self.sync(resource, [.manual]) }
        }
      }
    }
  }

  private func resetAutoSync() async {
    VitalLogger.healthKit.info("begin", source: "Reset")

    await scope.cancel()

    VitalLogger.healthKit.info("cancelled outstanding tasks", source: "Reset")

    await store.disableBackgroundDelivery()

    // Install a new clean scope.
    scope = SupervisorScope()

    backgroundDeliveryTask = nil
    backgroundDeliveryEnabled.set(value: false)

    SyncProgressStore.shared.clear()
    storage.clean()

    VitalLogger.healthKit.info("done", source: "Reset")
  }

  private func getLocalSyncState(
    syncID: SyncProgress.SyncID? = nil,
    forceRemoteCheck: Bool = false
  ) async throws -> LocalSyncState {
    // If we have a LocalSyncState with valid TTL, return it.
    if
      let state = storage.getLocalSyncState(),
      forceRemoteCheck == false && state.expiresAt > Date()
    {
      try checkSyncState(state)
      return state
    }

    guard backendSyncStateParkingLot.tryTo(.enable) else {
      try await backendSyncStateParkingLot.parkIfNeeded()

      // Try again
      return try await getLocalSyncState(syncID: syncID)
    }

    defer { _ = backendSyncStateParkingLot.tryTo(.disable) }

    // Double check if a LocalSyncState could have already been computed concurrently
    // between getLocalSyncState() and tryTo(.enable).
    if
      let state = storage.getLocalSyncState(),
      forceRemoteCheck == false && state.expiresAt > Date()
    {
      try checkSyncState(state)
      return state
    }

    if let syncID = syncID {
      VitalLogger.healthKit.info("revalidating", source: "LocalSyncState")
      SyncProgressStore.shared.recordSync(syncID, .revalidatingSyncState)
    }

    let previousState = storage.getLocalSyncState()
    let configuration = await configuration.get()

    switch configuration.connectionPolicy {
    case .autoConnect:
      // Make sure a connection is automatically created or reinstated.
      try await vitalClient.checkConnectedSource(.appleHealthKit)

    case .explicit:
      // The sdkStateSync() call will report status=error if the connection has been destroyed
      // by the Junction API. So no action to take here.
      break
    }

    let now = Date()
    let proposedStart = Date.dateAgo(now, days: configuration.numberOfDaysToBackFill)

    let backendState = try await vitalClient.sdkStateSync(
      UserSDKSyncStateBody(
        tzinfo: TimeZone.current.identifier,
        requestStartDate: proposedStart,
        requestEndDate: now
      )
    )

    let state = LocalSyncState(
      status: backendState.status,

      historicalStageAnchor: previousState?.historicalStageAnchor ?? now,
      defaultDaysToBackfill: previousState?.defaultDaysToBackfill ?? configuration.numberOfDaysToBackFill,
      teamDataPullPreferences: previousState?.teamDataPullPreferences ?? backendState.pullPreferences,

      ingestionStart: backendState.ingestionStart ?? previousState?.ingestionStart ?? .distantPast,

      // The query upper bound (end date for historical & daily) is normally open-ended.
      // In other words, `ingestionEnd` is typically nil.
      //
      // The only exception is if an ingestion end was set, in which case the most up-to-date
      // ingestion end date dictates the query upper bound.
      ingestionEnd: backendState.requestEndDate,

      perDeviceActivityTS: backendState.perDeviceActivityTs ?? false,

      // When we should revalidate the LocalSyncState again.
      expiresAt: Date().addingTimeInterval(Double(backendState.expiresIn ?? 14400)),

      reportingInterval: backendState.reportingInterval ?? previousState?.reportingInterval
    )

    try storage.setLocalSyncState(state)
    _connectionStatusDidChange.send(())

    try checkSyncState(state)

    return state
  }

  private func checkSyncState(_ state: LocalSyncState) throws {
    switch state.status {
    case .paused:
      VitalLogger.healthKit.info("connection is paused", source: "LocalSyncState")
      throw VitalHealthKitClientError.connectionPaused

    case .error:
      VitalLogger.healthKit.info("connection is destroyed", source: "LocalSyncState")
      throw VitalHealthKitClientError.connectionDestroyed

    case .active, nil:
      break
    }
  }

  private func computeSyncInstruction(
    _ resource: RemappedVitalResource,
    syncID: SyncProgress.SyncID
  ) async throws -> (SyncInstruction, LocalSyncState) {

    let state = try await getLocalSyncState(syncID: syncID)

    let hasCompletedHistoricalStage = storage.historicalStageDone(for: resource)
    || resource.wrapped == .profile

    let now = Date()
    let query = state.historicalStartDate(for: resource.wrapped) ..< (state.ingestionEnd ?? now)

    let instruction = SyncInstruction(stage: hasCompletedHistoricalStage ? .daily : .historical, query: query)

    if !hasCompletedHistoricalStage {
      // Report historical stage range
      try await vitalClient.sdkStartHistoricalStage(
        UserSDKHistoricalStageBeginBody(
          rangeStart: query.lowerBound,
          rangeEnd: query.upperBound,
          backfillType: resource.wrapped.backfillType
        )
      )
    }

    return (instruction, state)
  }

  private func prioritizeSync(_ remappedResource: RemappedVitalResource, _ tags: Set<SyncContextTag>) async throws -> Bool {
    if storage.historicalStageDone(for: remappedResource) {
      // Prioritization only affects historical stage.
      // If the resource is done with historical stage, it should not be subject to prioritization.
      return true
    }

    let priority = remappedResource.wrapped.priority
    let prerequisites = VitalResource.all.filter { $0.priority < priority }

    let state = try await authorizationState(store: self.store)
    let resourcesToCheck = state.activeResources
      .intersection(prerequisites.map(VitalHealthKitStore.remapResource))

    let syncProgress = SyncProgressStore.shared.get()

    // Can proceed only when all higher priority resources have finished their historical stage.
    // If resourcesToCheck is empty, this returns true, i.e., no waiting.
    return resourcesToCheck.allSatisfy { resource in
      if storage.historicalStageDone(for: resource) {
        return true
      }

      if let latestSync = syncProgress.backfillTypes[resource.wrapped.backfillType]?.latestSync {
        // IF historical stage not done, but last status is not in progress (incl. deprioritized)
        // We will let it through.
        // This ensures overall forward progress if one particular resource is erroring or stuck
        // for unforseen issues.
        return !latestSync.lastStatus.isInProgress
      }

      return false
    }
  }

  private func sync(_ remappedResource: RemappedVitalResource, _ tags: Set<SyncContextTag>) async {
    let progressStore = SyncProgressStore.shared
    let progressReporter = SyncProgressReporter.shared

    var syncID = SyncProgress.SyncID(resource: remappedResource.wrapped, tags: tags)

    let resource = remappedResource.wrapped
    let description = resource.logDescription

    guard self.pauseSynchronization == false else {
      VitalLogger.healthKit.info("[\(description)] skipped (sync paused)", source: "Sync")
      return
    }

    let parkingLot = self.syncSerializerLock.withLock {
      if let parkingLot = self.syncSerializer[remappedResource] {
        return parkingLot
      }

      let newLot = ParkingLot()
      self.syncSerializer[remappedResource] = newLot
      return newLot
    }

    // Use ParkingLot to ensure that — for each `RemappedVitalResource` — there can only be one
    // `sync()` call actually carrying out the sync work.
    //
    // All other subsequent callers would just wait in the ParkingLot until the sync work is done.
    //
    // This defends the SDK against flood of HKObserverQuery callouts, presumably caused by some
    // apps saving each HKSample individually, rather than in batches.
    // (e.g., Oura as at July 2024)
    guard parkingLot.tryTo(.enable) else {
      VitalLogger.healthKit.info("[\(description)] +1 parked; \(tags)", source: "Sync")

      // Throw CancellationError, which we can gracefully ignore.
      try? await parkingLot.parkIfNeeded()

      VitalLogger.healthKit.info("[\(description)] -1 parked; \(tags)", source: "Sync")
      return
    }
    defer { _ = parkingLot.tryTo(.disable) }

    defer { progressStore.flush() }

    let canProceed: Bool

    do {
      canProceed = try await self.prioritizeSync(remappedResource, tags)
    } catch let error {
      progressStore.recordError(syncID, error, context: "prioritizeSync")
      return
    }

    guard canProceed else {
      VitalLogger.healthKit.info("[\(description)] skipped (sync deprioritized)", source: "Sync")
      progressStore.recordSync(syncID, .deprioritized)
      return
    }

    VitalLogger.healthKit.info("[\(description)] begin \(tags)", source: "Sync")

    guard let configuration = configuration.value else {
      VitalLogger.healthKit.info("[\(description)] configuration unavailable", source: "Sync")
      return
    }

    progressStore.recordSync(syncID, .started)
    progressReporter.syncBegin(syncID)

    // Make sure the entry in UserHistoryStore for today is up to date.
    UserHistoryStore.shared.record(TimeZone.current)

    // If we receive this payload in foreground, wrap the sync work in
    // a UIKit background task, in case the user will move the app to background soon.

    let osBackgroundTask: ProtectedBox<UIBackgroundTaskIdentifier>?

    if AppStateTracker.shared.state.status == .foreground {
      osBackgroundTask = ProtectedBox<UIBackgroundTaskIdentifier>()
      osBackgroundTask!.start("vital-sync-\(description)", expiration: {
        progressStore.flush()
      })
      VitalLogger.healthKit.info("started: daily:\(description)", source: "UIKitBgTask")

    } else {
      osBackgroundTask = nil
    }

    // IMPORTANT: Must be called on ALL exit paths below.
    // Pay extra attention when doing early exits with returns and throws.
    func syncEnded(success: Bool) async {
      if success {
        scheduleDeprioritizedResourceRetries()
      }

      await progressReporter.syncEnded(syncID)

      if let osBackgroundTask = osBackgroundTask {
        osBackgroundTask.endIfNeeded()
        VitalLogger.healthKit.info("ended: daily:\(description)", source: "UIKitBgTask")
      }
    }

    let instruction: SyncInstruction
    let state: LocalSyncState

    do {
      (instruction, state) = try await computeSyncInstruction(remappedResource, syncID: syncID)

      if instruction.stage == .historical {
        syncID.tags.insert(.historicalStage)
      }

    } catch let error {
      progressStore.recordError(syncID, error, context: "[\(description)] sync instruction")
      await syncEnded(success: false)
      return
    }

    VitalLogger.healthKit.info("[\(description)] \(instruction)", source: "Sync")

    // Signal syncing (so the consumer can convey it to the user)
    _status.send(.syncing(resource))

    @Sendable func readStep(uncommittedAnchors: [StoredAnchor]) async throws -> (ProcessedResourceData?, [StoredAnchor], hasMore: Bool) {
      // Fetch from HealthKit
      let (data, anchors): (ProcessedResourceData?, [StoredAnchor])

      (data, anchors) = try await store.readResource(
        remappedResource,
        instruction,
        AnchorStorageOverlay(wrapped: self.storage, uncommittedAnchors: uncommittedAnchors),
        ReadOptions(
          perDeviceActivityTS: state.perDeviceActivityTS,
          sleepDataAllowlist: configuration.sleepDataAllowlist
        )
      )

      // Continue the loop if any anchor reports hasMore=true.
      let hasMore = anchors.contains(where: \.hasMore)

      return (data, anchors, hasMore)
    }

    @Sendable func uploadStep(
      data: ProcessedResourceData?,
      anchors: [StoredAnchor],
      hasMore: Bool
    ) async throws -> Int {

      // We skip empty POST only in daily stage.
      // Empty POST is sent for historical stage, so we would consistently emit
      // historical.data.*.created events.
      guard
        let data = data,
        instruction.stage == .historical || data.shouldSkipPost == false
      else {

        VitalLogger.healthKit.info("[\(description)] no data to upload", source: "Sync")
        _status.send(.nothingToSync(resource))

        return 0
      }

      if configuration.mode.isAutomatic {
        VitalLogger.healthKit.info("[\(description)] begin upload: \(instruction.stage)\(data.shouldSkipPost ? ",empty" : "")", source: "Sync")

        // Post data
        try await vitalClient.post(
          data,
          instruction.taggedPayloadStage,
          .appleHealthKit,
          /// We can't use `vitalCalendar` here. We want to send the user's timezone
          /// rather than UTC (which is what `vitalCalendar` is set to).
          TimeZone.current,
          // Is final chunk?
          hasMore == false
        )
      } else {
        VitalLogger.healthKit.info("[\(description)] upload skipped in manual mode", source: "Sync")
      }


      // Save the anchor/date on a succesfull network call
      anchors.forEach(storage.store(entity:))

      // Signal success
      _status.send(.successSyncing(resource, data))

      VitalLogger.healthKit.info("[\(description)] completed: \(hasMore ? "hasMore" : "noMore")", source: "Sync")
      return data.dataCount
    }

    // Overlap read and upload, so we maximize the use of limited background execution time.
    //
    // .read -> .upload
    //           .read  -> .upload
    //                      .read -> .upload
    //                                 (fin)

    let (pipeline, pipelineScheduler) = AsyncStream<PipelineStage>.makeStream()
    pipelineScheduler.yield(.read())

    let uploadSemaphore = ParkingLot().semaphore

    let success = await withTaskGroup(of: Void.self, returning: Bool.self) { group in
      defer { pipelineScheduler.finish() }

      for await stage in pipeline {
        switch stage {
        case let .read(uncommittedAnchors):
          _ = group.addTaskUnlessCancelled {
            let signpost = VitalLogger.Signpost.begin(name: "read", description: description)
            defer { signpost.end() }

            do {
              let (data, anchors, hasMore) = try await readStep(uncommittedAnchors: uncommittedAnchors)
              pipelineScheduler.yield(.upload(data, anchors, hasMore: hasMore))

            } catch is CancellationError {
              pipelineScheduler.yield(.cancelled)

            } catch is TimeoutError {
              pipelineScheduler.yield(.timedOut)

            } catch let error {
              pipelineScheduler.yield(.error(error))
            }
          }

        case let .upload(data, anchors, hasMore: hasMore):
          progressStore.recordSync(syncID, .readChunk)

          _ = group.addTaskUnlessCancelled { [syncID] in
            do {
              try await VitalLogger.Signpost
                .begin(name: "wait-for-outstanding-upload", description: description)
                .endWith {
                  try await uploadSemaphore.acquire()
                }

              defer { uploadSemaphore.release() }

              let signpost2 = VitalLogger.Signpost.begin(name: "upload", description: description)
              defer { signpost2.end() }

              // Schedule an overlapping read
              if hasMore {
                pipelineScheduler.yield(.read(uncommittedAnchors: anchors))
              }

              let dataCount = try await uploadStep(data: data, anchors: anchors, hasMore: hasMore)
              progressStore.recordSync(syncID, dataCount >= 0 ? .uploadedChunk : .noData, dataCount: dataCount)

              if !hasMore {
                pipelineScheduler.yield(.success)
              }

            } catch is CancellationError {
              pipelineScheduler.yield(.cancelled)

            } catch is TimeoutError {
              pipelineScheduler.yield(.timedOut)

            } catch let error {
              pipelineScheduler.yield(.error(error))
            }
          }

        case .cancelled:
          progressStore.recordSync(syncID, .cancelled)
          VitalLogger.healthKit.info("[\(description)] cancelled", source: "Sync")
          return false

        case .timedOut:
          progressStore.recordSync(syncID, .timedOut)
          VitalLogger.healthKit.info("[\(description)] timedOut", source: "Sync")
          return false

        case let .error(error):
          progressStore.recordError(syncID, error, context: "ReadAndUpload")
          return false

        case .success:
          self.storage.markHistoricalStageDone(for: remappedResource)
          progressStore.recordSync(syncID, .completed)
          VitalLogger.healthKit.info("[\(description)] completed", source: "Sync")
          return true
        }
      }

      return false
    }

    await syncEnded(success: success)
  }

  private func scheduleDeprioritizedResourceRetries() {
    scope.task(priority: .high) { @MainActor in
      guard AppStateTracker.shared.state.status == .foreground else {
        return
      }

      let deprioritized = SyncProgressStore.shared.get().backfillTypes
        .filter { $0.value.latestSync?.lastStatus == .deprioritized }
        .map { $0.key }
        .compactMap(VitalResource.init)
        .map(VitalHealthKitStore.remapResource(_:))

      // Retry previously deprioritized resources.
      //
      // If their prerequisites still were not satisfied, they will re-enter
      // `syncDeprioritizedQueue` eventually.
      await withTaskGroup(of: Void.self) { group in
        for resource in Set(deprioritized) {
          group.addTask {
            await self.sync(resource, [])
          }
        }
      }
    }
  }

  /// Ask for health data read and write permission from the user.
  ///
  /// The interactive permission prompt is managed by the operating system (Apple iOS). Vital SDK cannot customize
  /// its appearance or behaviour.
  ///
  /// The prompt only appears for resources being asked for the first time. iOS typically ignores any subsequent attempts,
  /// regardless of whether permission has been granted or denied during that first time. You will have to direct your users to
  /// either the Settings ap or the Apple Health app for reviewing and updating the permissions.
  ///
  /// - Parameter readPermissions: `VitalResource`s to request read permission for.
  /// - Parameter writePermissions: `VitalResource`s to request write permission for.
  /// - Parameter extraReadPermissions: Extra HealthKit object types whose read permissions should be requested in addition to the needs of Vital SDK.
  /// - Parameter extraWritePermissions: Extra HealthKit sample types whose write permissions should be requested in addition to the needs of Vital SDK.
  /// - Parameter dataTypeAllowlist: If not `nil`, only the specified data types would be requested. This applies to both
  ///   SDK originated requests as well as extra permissions you specified above.
  ///
  public func ask(
    readPermissions readResources: [VitalResource],
    writePermissions writeResource: [WritableVitalResource],
    extraReadPermissions: [HKObjectType] = [],
    extraWritePermissions: [HKSampleType] = [],
    dataTypeAllowlist: Set<HKObjectType>? = nil
  ) async -> PermissionOutcome {

    guard store.isHealthDataAvailable() else {
      return .healthKitNotAvailable
    }


    do {
      try await store.requestReadWriteAuthorization(readResources, writeResource, extraReadPermissions, extraWritePermissions, dataTypeAllowlist)

      let state = try await authorizationState(store: store)
      SyncProgressStore.shared.recordAsk(state.activeResources)
      SyncProgressStore.shared.flush()

      if let configuration = self.configuration.value {
        if configuration.connectionPolicy == .autoConnect {

          // We have gone through Ask successfully. Check if a connected source has been created.
          do {
            try await VitalClient.shared.checkConnectedSource(for: .appleHealthKit)

          } catch let error {
            VitalLogger.healthKit.info("proactive CS creation failed; error = \(error)", source: "Ask")
          }
        }

        try await checkBackgroundUpdates(
          isBackgroundEnabled: configuration.backgroundDeliveryEnabled
        )
        scheduleUnnotifiedResourceRescue()
      }

      return .success

    } catch is NothingToRequest {
      let message = "No data type to request due to data type allowlist"
      VitalLogger.healthKit.info("\(message)", source: "Ask")
      return .failure(message)

    } catch let error {
      return .failure(error.localizedDescription)
    }
  }

  @available(*, deprecated, message: "Use `permissionStatus(for:)`.")
  public func hasAskedForPermission(resource: VitalResource) -> Bool {
    store.authorizationStateSync(resource).isActive
  }

  public func permissionStatus(for resources: [VitalResource]) async throws -> [VitalResource: PermissionStatus] {
    try await withThrowingTaskGroup(of: (VitalResource, PermissionStatus).self, returning: [VitalResource: PermissionStatus].self) { group in
      for resource in resources {
        group.addTask {
          let state = try await self.store.authorizationState(resource)
          return (
            resource,
            state.isActive ? PermissionStatus.asked : PermissionStatus.notAsked
          )
        }
      }

      return try await group.reduce(into: [:]) { $0[$1.0] = $1.1 }
    }
  }

  public static func healthKitRequirements(for resource: VitalResource) -> HealthKitObjectTypeRequirements {
    return toHealthKitTypes(resource: resource)
  }

  @available(*, deprecated, message:"Use `VitalHealthKitClient.shared.syncProgress`.")
  public func dateOfLastSync(for resource: VitalResource) -> Date? {
    return SyncProgressStore.shared.get().backfillTypes[resource.backfillType]?.latestSync?.end
  }
}

extension VitalHealthKitClient {

  /// The current connection status of the Health SDK.
  /// - seealso: `Configuration.connectionPolicy`
  public var connectionStatus: ConnectionStatus {
    switch configuration.value?.connectionPolicy {
    case .autoConnect, nil:
      return .autoConnect

    case .explicit:
      let state = storage.getLocalSyncState()
      switch state?.status {
      case .active:
        return .connected
      case .paused:
        return .connectionPaused
      case .error, nil:
        return .disconnected
      }
    }
  }

  public var connectionStatuses: AsyncStream<ConnectionStatus> {
    AsyncStream<ConnectionStatus> { continuation in
      let cancellable = connectionStatusPublisher()
        .sink { _ in continuation.finish() } receiveValue: { continuation.yield($0) }
      continuation.onTermination = { _ in cancellable.cancel() }
    }
  }

  public func connectionStatusPublisher() -> some Publisher<ConnectionStatus, Never> {
    Deferred { self._connectionStatusDidChange.prepend(()).map { _ in self.connectionStatus } }
  }

  /// Setup a HealthKit connection with this device.
  ///
  /// - precondition: You must configure the Health SDK to use `VitalHealthKitClient.ConnectionPolicy.explicit`.
  public func connect() async throws {
    let configuration = await configuration.get()

    guard configuration.connectionPolicy == .explicit else {
      throw VitalHealthKitClientError.disabledFeature("connect() only works with ConnectionPolicy.explicit.")
    }

    try await connectDisconnectParkingLot.semaphore.acquire()
    defer { connectDisconnectParkingLot.semaphore.release() }

    try await vitalClient.checkConnectedSource(.appleHealthKit)

    do {
      _ = try await getLocalSyncState(forceRemoteCheck: true)

      // Connection is created as expected.
      try await checkBackgroundUpdates(
        isBackgroundEnabled: configuration.backgroundDeliveryEnabled
      )
      scheduleUnnotifiedResourceRescue()

    } catch VitalHealthKitClientError.connectionDestroyed {
      throw VitalHealthKitClientError.sdkInvalidState("connection has been destroyed concurrently through the Junction API")

    } catch let error {
      // Passthrough other errors
      throw error
    }
  }

  /// Disconnect the active HealthKit connection on this device.
  ///
  /// - precondition: You must configure the Health SDK to use `VitalHealthKitClient.ConnectionPolicy.explicit`.
  public func disconnect() async throws {
    let configuration = await configuration.get()

    guard configuration.connectionPolicy == .explicit else {
      throw VitalHealthKitClientError.disabledFeature("disconnect() only works with ConnectionPolicy.explicit.")
    }

    try await connectDisconnectParkingLot.semaphore.acquire()
    defer { connectDisconnectParkingLot.semaphore.release() }

    try await vitalClient.deregisterProvider(.appleHealthKit)

    do {
      _ = try await getLocalSyncState(forceRemoteCheck: true)

      // Connection is still active unexpectedly.
      throw VitalHealthKitClientError.sdkInvalidState("connection has been re-instated concurrently by another SDK installation")

    } catch VitalHealthKitClientError.connectionDestroyed {
      // Connection is destroyed as expected
      await resetAutoSync()
      return

    } catch let error {
      // Passthrough other errors
      throw error
    }

  }

}

enum BackgroundDeliveryStage {
  case received(BackgroundDeliveryPayload)
  case evaluate
}

enum PipelineStage {
  case read(uncommittedAnchors: [StoredAnchor] = [])
  case upload(ProcessedResourceData?, [StoredAnchor], hasMore: Bool)

  case error(Error)
  case success
  case cancelled
  case timedOut

  var description: String {
    switch self {
    case .read:
      return "read"
    case let .upload(_, _, hasMore):
      return "upload(\(hasMore ? "hasMore" : "noMore"))"
    case .error:
      return "error"
    case .cancelled:
      return "cancelled"
    case .timedOut:
      return "timedOut"
    case .success:
      return "success"
    }
  }
}

extension VitalHealthKitClient {
  public static func read(resource: VitalResource, startDate: Date, endDate: Date) async throws -> ProcessedResourceData? {

    let (data, _): (ProcessedResourceData?, [StoredAnchor]) = try await VitalHealthKit.read(
      resource: VitalHealthKitStore.remapResource(resource),
      healthKitStore:  HKHealthStore(),
      vitalStorage: VitalHealthKitStorage(storage: .debug),
      instruction: SyncInstruction(stage: .daily, query: startDate ..< endDate),
      options: ReadOptions()
    )

    return data
  }
}

#if WriteAPI
extension VitalHealthKitClient {
  public func write(input: DataInput, startDate: Date, endDate: Date) async throws -> Void {
    try await self.store.writeInput(input, startDate, endDate)
  }

  public static func write(input: DataInput, startDate: Date, endDate: Date) async throws -> Void {
    let store = HKHealthStore()
    try await VitalHealthKit.write(healthKitStore: store, dataInput: input, startDate: startDate, endDate: endDate)
  }
}
#endif

extension VitalHealthKitClient {
  /// Pause all synchronization, both automatic syncs and any manual `syncData(_:)` calls.
  ///
  /// - note: When unpausing, a sync is automatically triggered on all previously asked-for resources.
  public var pauseSynchronization: Bool {
    get { self.storage.shouldPauseSynchronization() }
    set {
      let oldValue = self.storage.shouldPauseSynchronization()
      self.storage.setPauseSynchronization(newValue)

      // Auto-trigger an asynchronous sync when we un-pause.
      if oldValue && !newValue {
        self.syncData()
      }
    }
  }

  public var syncProgress: SyncProgress {
    SyncProgressStore.shared.get()
  }

  public var syncProgresses: AsyncStream<SyncProgress> {
    AsyncStream<SyncProgress> { continuation in
      let cancellable = syncProgressPublisher()
        .sink { _ in continuation.finish() } receiveValue: { continuation.yield($0) }
      continuation.onTermination = { _ in cancellable.cancel() }
    }
  }

  public func syncProgressPublisher() -> some Publisher<SyncProgress, Never> {
    SyncProgressStore.shared.publisher()
  }

}

extension ProtectedBox<UIBackgroundTaskIdentifier> {
  func start(_ name: String, expiration: @escaping () -> Void) {
    let taskId = UIApplication.shared.beginBackgroundTask(withName: name) { [weak self] in
      expiration()
      self?.endIfNeeded()
    }
    set(value: taskId)
  }

  func endIfNeeded() {
    if let taskId = clean() {
      UIApplication.shared.endBackgroundTask(taskId)
    }
  }
}

private func healthkitCalloutEventType(_ state: AppState.Status) -> SyncProgress.SystemEventType {
  switch state {
  case .background:
    return .healthKitCalloutBackground
  case .foreground:
    return .healthKitCalloutForeground
  case .launching:
    return .healthKitCalloutAppLaunching
  case .terminating:
    return .healthKitCalloutAppTerminating
  }
}

extension SyncProgressStore {
  fileprivate func recordError(
    _ syncID: SyncProgress.SyncID,
    _ error: any Error,
    context: String
  ) {
    let errorSummary = "\(context) \(summarizeError(error))"

    var status = SyncProgress.SyncStatus.error

    if let error = error as? HKError {
      if error.code == .errorDatabaseInaccessible {
        // Device is locked. Sync fails expectedly.
        status = .expectedError
      }

    } else if let error = error as? VitalKeychainError {
      if case .interactionNotAllowed = error {
        // Device is locked. Sync fails expectedly.
        status = .expectedError
      }

    } else if let error = error as? VitalHealthKitClientError {
      if case .connectionPaused = error {
        // Connection is paused. Sync fails expectedly.
        status = .connectionPaused

      } else if case .connectionDestroyed = error {
        status = .connectionDestroyed
      }

    } else if let error = error as? VitalClient.Error {
      if case .notConfigured = error {
        // SDK is not configured or is being reset due to sign-out. Sync fails expectedly.
        status = .expectedError
      }
    }

    recordSync(syncID, status, errorDetails: errorSummary)
    VitalLogger.healthKit.error("\(status) \(errorSummary)", source: "Sync")
  }
}
