import HealthKit
import Combine
import os.log
import UIKit
@_spi(VitalSDKInternals) import VitalCore

public enum PermissionOutcome: Equatable {
  case success
  case failure(String)
  case healthKitNotAvailable
}

@objc public class VitalHealthKitClient: NSObject {
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

  let configuration: ProtectedBox<Configuration>

  let syncSerializerLock = NSLock()
  var syncSerializer: [RemappedVitalResource: ParkingLot] = [:]


  private var isAutoSyncConfigured: Bool {
    backgroundDeliveryEnabled.value ?? false
  }
  
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
    core.childSDKShouldReset
      .sink {
        Task {
          await client.resetAutoSync()
        }
      }
      .store(in: &client.cancellables)
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
    
    if backgroundDeliveryEnabled.value != true {
      backgroundDeliveryEnabled.set(value: true)

      checkBackgroundUpdates(isBackgroundEnabled: configuration.backgroundDeliveryEnabled)
    }
  }
}

public extension VitalHealthKitClient {
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
    
    public init(
      backgroundDeliveryEnabled: Bool = false,
      numberOfDaysToBackFill: Int = 90,
      logsEnabled: Bool = true,
      mode: DataPushMode = .automatic
    ) {
      self.backgroundDeliveryEnabled = backgroundDeliveryEnabled
      self.numberOfDaysToBackFill = min(numberOfDaysToBackFill, 365)
      self.logsEnabled = logsEnabled
      self.mode = mode
    }
  }

  private struct BackgroundDeliveryTask {
    let task: Task<Void, Error>
    let resources: Set<RemappedVitalResource>
    let streamContinuation: AsyncStream<BackgroundDeliveryPayload>.Continuation

    func cancel() {
      streamContinuation.finish()
      task.cancel()
    }
  }
}

extension VitalHealthKitClient {
  
  private func checkBackgroundUpdates(isBackgroundEnabled: Bool) {
    guard isBackgroundEnabled else { return }

    let resources = Set(
      resourcesAskedForPermission(store: self.store)
        .map(VitalHealthKitStore.remapResource)
    )
    let currentTask = self.backgroundDeliveryTask

    // Reconfigure the task only if the set of resources has changed, or we have not configured it
    // before.
    guard resources != currentTask?.resources else { return }
    
    /// If it's already running, cancel it
    currentTask?.cancel()

    let allowedSampleTypes = Set(
      resources.lazy.map(\.wrapped)
        .map(toHealthKitTypes(resource:))
        .flatMap(\.allObjectTypes)
    )

    let set: [Set<HKObjectType>] = observedSampleTypes().map(Set.init)
    let common: [[HKSampleType]] = set.map { $0.intersection(allowedSampleTypes) }.map { $0.compactMap { $0 as? HKSampleType } }
    let cleaned: Set<[HKSampleType]> = Set(common.filter { $0.isEmpty == false })

    let uniqueFlatenned: Set<HKSampleType> = Set(cleaned.flatMap { $0 })

    if uniqueFlatenned.isEmpty {
      VitalLogger.healthKit.info("Not observing any type")
    }

    /// Enable background deliveries
    enableBackgroundDelivery(for: uniqueFlatenned)

    let stream: AsyncStream<BackgroundDeliveryPayload>
    let streamContinuation: AsyncStream<BackgroundDeliveryPayload>.Continuation

    if #available(iOS 15.0, *) {
      (stream, streamContinuation) = bundledBackgroundObservers(for: cleaned)
    } else {
      (stream, streamContinuation) = backgroundObservers(for: uniqueFlatenned)
    }

    let task = Task<Void, any Error>(priority: .high) { @MainActor in
      for await payload in stream {
        // If the task is cancelled, we would break the endless iteration and end the task.
        // Any buffered payload would not be processed, and is expected to be redelivered by
        // HealthKit.
        //
        // > https://developer.apple.com/documentation/healthkit/hkhealthstore/1614175-enablebackgrounddelivery#3801028
        // > If you don’t call the update’s completion handler, HealthKit continues to attempt to
        // > launch your app using a backoff algorithm to increase the delay between attempts.
        if Task.isCancelled {
          payload.completion(.cancelled)
          continue
        }

        // Allow multiple resource sync to run concurrently.
        Task(priority: .high) {
          // Task is not cancelled — we must call the HealthKit completion handler irrespective of
          // the sync process outcome. This is to avoid triggering the "strike on 3rd missed delivery"
          // rule of HealthKit background delivery.
          //
          // Since we have fairly frequent delivery anyway, each of which will implicit retry from
          // where the last sync has left off, this unconfigurable exponential backoff retry
          // behaviour adds little to no value in maintaining data freshness.
          //
          // (except for the task cancellation redelivery expectation stated above).
          defer { payload.completion(.completed) }

          VitalLogger.healthKit.info("received: \(payload.sampleTypes.map(\.shortenedIdentifier))", source: "BgDelivery")

          guard let first = payload.sampleTypes.first else {
            return
          }

          /// This means we are trying to sync related samples, so let's convert it to a `VitalResource`
          let resource = VitalHealthKitStore.remapResource(store.toVitalResource(first))
          await sync(resource, foreground: payload.appState != .background)
        }
      }
    }

    self.backgroundDeliveryTask = BackgroundDeliveryTask(
      task: task,
      resources: Set(resources),
      streamContinuation: streamContinuation
    )
  }
  
  private func enableBackgroundDelivery(for sampleTypes: Set<HKSampleType>) {
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

  @available(iOS 15.0, *)
  private func bundledBackgroundObservers(
    for typesBundle: Set<[HKSampleType]>
  ) -> (AsyncStream<BackgroundDeliveryPayload>, AsyncStream<BackgroundDeliveryPayload>.Continuation) {

    var _continuation: AsyncStream<BackgroundDeliveryPayload>.Continuation!

    let stream = AsyncStream<BackgroundDeliveryPayload> { continuation in
      _continuation = continuation

      var queries: [HKObserverQuery] = []

      for typesToObserve in typesBundle {

        let descriptors = typesToObserve.map {
          HKQueryDescriptor(sampleType: $0, predicate: nil)
        }

        let query = HKObserverQuery(queryDescriptors: descriptors) { query, sampleTypes, handler, error in

          guard let sampleTypes = sampleTypes else {
            VitalLogger.healthKit.error("Failed to background deliver. Empty samples")
            return
          }

          guard error == nil else {
            VitalLogger.healthKit.error("observer errored for \(typesToObserve.map(\.shortenedIdentifier)); error = \(String(describing: error)).")

            ///  We need a better way to handle if a failure happens here.
            return
          }

          VitalLogger.healthKit.info("notified: \(sampleTypes.map(\.shortenedIdentifier))", source: "HealthKit")

          // It appears that the iOS 15+ HKObserverQuery might pass us `HKSampleType`s that is
          // outside the conditions we specified via `descriptors`. Filter out any unsolicited types
          // before proceeding.
          let filteredSampleTypes = sampleTypes.intersection(typesToObserve)

          if filteredSampleTypes.isEmpty {
            handler()
          } else {
            Task(priority: .userInitiated) { @MainActor in
              let payload = BackgroundDeliveryPayload(
                sampleTypes: filteredSampleTypes,
                completion: { completion in
                  if completion == .completed {
                    handler()
                  }
                },
                appState: UIApplication.shared.applicationState
              )
              continuation.yield(payload)
            }
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
    for sampleTypes: Set<HKSampleType>
  ) -> (AsyncStream<BackgroundDeliveryPayload>, AsyncStream<BackgroundDeliveryPayload>.Continuation) {
    var _continuation: AsyncStream<BackgroundDeliveryPayload>.Continuation!

    let stream = AsyncStream<BackgroundDeliveryPayload> { continuation in
      _continuation = continuation

      var queries: [HKObserverQuery] = []
      
      for sampleType in sampleTypes {
        let query = HKObserverQuery(sampleType: sampleType, predicate: nil) { query, handler, error in

          guard error == nil else {
            VitalLogger.healthKit.error("Failed to background deliver for \(sampleType.identifier).")
            
            ///  We need a better way to handle if a failure happens here.
            return
          }

          VitalLogger.healthKit.info("notified: \(sampleType.shortenedIdentifier)", source: "HealthKit")

          Task(priority: .userInitiated) { @MainActor in
            let payload = BackgroundDeliveryPayload(
              sampleTypes: Set([sampleType]),
              completion: { completion in
                if completion == .completed {
                  handler()
                }
              },
              appState: UIApplication.shared.applicationState
            )
            continuation.yield(payload)
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
  
  public func syncData() {
    let resources = resourcesAskedForPermission(store: store)
    syncData(for: Array(resources))
  }
  
  public func syncData(for resources: [VitalResource]) {
    Task(priority: .high) {
      let remappedResources = Set(resources.map(VitalHealthKitStore.remapResource(_:)))

      for resource in remappedResources {
        await sync(resource, foreground: true)
      }
      
      _status.send(.syncingCompleted)
    }
  }

  private func resetAutoSync() async {
    backgroundDeliveryTask?.task.cancel()
    backgroundDeliveryTask = nil
    backgroundDeliveryEnabled.set(value: false)

    await store.disableBackgroundDelivery()
  }

  private func getLocalSyncState() async throws -> LocalSyncState {
    // If we have a LocalSyncState with valid TTL, return it.
    if 
      let state = storage.getLocalSyncState(),
      state.expiresAt > Date()
    {
      return state
    }

    guard backendSyncStateParkingLot.tryTo(.enable) else {
      try await backendSyncStateParkingLot.parkIfNeeded()

      // Try again
      return try await getLocalSyncState()
    }

    defer { _ = backendSyncStateParkingLot.tryTo(.disable) }

    // Double check if a LocalSyncState could have already been computed concurrently
    // between getLocalSyncState() and tryTo(.enable).
    if
      let state = storage.getLocalSyncState(),
      state.expiresAt > Date()
    {
      return state
    }

    VitalLogger.healthKit.info("revalidating", source: "LocalSyncState")

    let previousState = storage.getLocalSyncState()
    let configuration = await configuration.get()

    /// Make sure the user has a connected source set up
    try await vitalClient.checkConnectedSource(.appleHealthKit)

    let now = Date()
    let proposedStart = Date.dateAgo(now, days: configuration.numberOfDaysToBackFill)

    let backendState = try await vitalClient.sdkStateSync(
      UserSDKSyncStateBody(
        tzinfo: TimeZone.current.identifier,
        requestStartDate: proposedStart,
        requestEndDate: now
      )
    )

    if backendState.status != .active {
      VitalLogger.healthKit.info("connection is paused", source: "LocalSyncState")
      throw VitalHealthKitClientError.connectionPaused
    }

    let state = LocalSyncState(
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
      expiresAt: Date().addingTimeInterval(Double(backendState.expiresIn ?? 14400))
    )

    try storage.setLocalSyncState(state)

    VitalLogger.healthKit.info("updated; \(state)", source: "LocalSyncState")

    return state
  }

  private func computeSyncInstruction(_ resource: VitalResource) async throws -> (SyncInstruction, LocalSyncState) {
    let state = try await getLocalSyncState()

    let hasCompletedHistoricalStage = storage.readFlag(for: resource)
      || resource == .profile

    let now = Date()
    let query = state.historicalStartDate(for: resource) ..< (state.ingestionEnd ?? now)

    let instruction = SyncInstruction(stage: hasCompletedHistoricalStage ? .daily : .historical, query: query)
    return (instruction, state)
  }

  private func sync(_ remappedResource: RemappedVitalResource, foreground: Bool) async {
    let resource = remappedResource.wrapped
    let description = resource.resourceToBackfillType().rawValue

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
      VitalLogger.healthKit.info("[\(description)] +1 parked; fg=\(foreground)", source: "Sync")

      // Throw CancellationError, which we can gracefully ignore.
      try? await parkingLot.parkIfNeeded()

      VitalLogger.healthKit.info("[\(description)] -1 parked; fg=\(foreground)", source: "Sync")
      return
    }
    defer { _ = parkingLot.tryTo(.disable) }

    VitalLogger.healthKit.info("[\(description)] begin fg=\(foreground)", source: "Sync")

    guard let configuration = configuration.value else {
      VitalLogger.healthKit.info("[\(description)] configuration unavailable", source: "Sync")
      return
    }

    // If we receive this payload in foreground, wrap the sync work in
    // a UIKit background task, in case the user will move the app to background soon.

    let osBackgroundTask: ProtectedBox<UIBackgroundTaskIdentifier>?

    if foreground {
      osBackgroundTask = ProtectedBox<UIBackgroundTaskIdentifier>()
      osBackgroundTask!.start("vital-sync-\(description)", expiration: {})
      VitalLogger.healthKit.info("started: daily:\(description)", source: "UIKitBgTask")

    } else {
      osBackgroundTask = nil
    }

    defer {
      if let osBackgroundTask = osBackgroundTask {
        osBackgroundTask.endIfNeeded()
        VitalLogger.healthKit.info("ended: daily:\(description)", source: "UIKitBgTask")
      }
    }

    do {
      let (instruction, state) = try await computeSyncInstruction(remappedResource.wrapped)

      VitalLogger.healthKit.info("[\(description)] \(instruction)", source: "Sync")

      // Signal syncing (so the consumer can convey it to the user)
      _status.send(.syncing(resource))

      var hasMore = false

      repeat {
        // Fetch from HealthKit
        let (data, anchors): (ProcessedResourceData?, [StoredAnchor])

        (data, anchors) = try await store.readResource(
          remappedResource,
          instruction,
          storage,
          ReadOptions(perDeviceActivityTS: state.perDeviceActivityTS)
        )

        // Continue the loop if any anchor reports hasMore=true.
        hasMore = anchors.contains(where: \.hasMore)

        // We skip empty POST only in daily stage.
        // Empty POST is sent for historical stage, so we would consistently emit
        // historical.data.*.created events.
        guard
          let data = data,
          instruction.stage == .historical || data.shouldSkipPost == false
        else {

          VitalLogger.healthKit.info("[\(description)] no data to upload", source: "Sync")
          _status.send(.nothingToSync(resource))

          return
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

        // This is used for calculating the stage (daily vs historical)
        storage.storeFlag(for: resource)

        // Save the anchor/date on a succesfull network call
        anchors.forEach(storage.store(entity:))

        // Signal success
        _status.send(.successSyncing(resource, data))

        VitalLogger.healthKit.info("[\(description)] completed: \(hasMore ? "hasMore" : "noMore")", source: "Sync")

      } while hasMore

    } catch let error {
      VitalLogger.healthKit.info("[\(description)] failed; error = \(error)", source: "Sync")
      _status.send(.failedSyncing(resource, error))
    }
  }
  
  public func ask(
    readPermissions readResources: [VitalResource],
    writePermissions writeResource: [WritableVitalResource]
  ) async -> PermissionOutcome {
    
    guard store.isHealthDataAvailable() else {
      return .healthKitNotAvailable
    }
    
    do {
      try await store.requestReadWriteAuthorization(readResources, writeResource)

      // We have gone through Ask successfully. Check if a connected source has been created.
      do {
        try await VitalClient.shared.checkConnectedSource(for: .appleHealthKit)

      } catch let error {
        VitalLogger.healthKit.info("proactive CS creation failed; error = \(error)", source: "Ask")
      }

      if configuration.isNil() == false {
        let configuration = await configuration.get()
        
        checkBackgroundUpdates(
          isBackgroundEnabled: configuration.backgroundDeliveryEnabled
        )
      }
      
      return .success
    }
    catch let error {
      return .failure(error.localizedDescription)
    }
  }
  
  public func hasAskedForPermission(resource: VitalResource) -> Bool {
    store.hasAskedForPermission(resource)
  }
  
  public func dateOfLastSync(for resource: VitalResource) -> Date? {
    guard hasAskedForPermission(resource: resource) else {
      return nil
    }
    
    let requirements = toHealthKitTypes(resource: resource)
    let dates: [Date] = requirements.allObjectTypes.map {
      String(describing: $0.self)
    }.compactMap { key in
      storage.read(key: key)?.date
    }
    
    /// This is not technically correct, because a resource (e.g. activity) can be made up of many types.
    /// In this case, we pick up the most recent one.
    return dates.sorted { $0.compare($1) == .orderedDescending }.first
  }
}

extension VitalHealthKitClient {
  public static func read(resource: VitalResource, startDate: Date, endDate: Date) async throws -> ProcessedResourceData? {

    let (data, _): (ProcessedResourceData?, [StoredAnchor]) = try await VitalHealthKit.read(
      resource: VitalHealthKitStore.remapResource(resource),
      healthKitStore:  HKHealthStore(),
      typeToResource: VitalHealthKitStore.live.toVitalResource,
      vitalStorage: VitalHealthKitStorage(storage: .debug),
      instruction: SyncInstruction(stage: .daily, query: startDate ..< endDate),
      options: ReadOptions(embedTimeseries: true)
    )

    return data
  }
}

extension VitalHealthKitClient {
  public func write(input: DataInput, startDate: Date, endDate: Date) async throws -> Void {
    try await self.store.writeInput(input, startDate, endDate)
  }
  
  public static func write(input: DataInput, startDate: Date, endDate: Date) async throws -> Void {
    let store = HKHealthStore()
    try await VitalHealthKit.write(healthKitStore: store, dataInput: input, startDate: startDate, endDate: endDate)
  }
}

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
