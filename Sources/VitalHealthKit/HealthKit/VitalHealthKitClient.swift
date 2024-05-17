import HealthKit
import Combine
import os.log
@_spi(VitalSDKInternals) import VitalCore
import UIKit

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

  private let store: VitalHealthKitStore
  private let storage: VitalHealthKitStorage
  private let secureStorage: VitalSecureStorage
  private let vitalClient: VitalClientProtocol
  
  private let _status: PassthroughSubject<Status, Never>
  private var backgroundDeliveryTask: BackgroundDeliveryTask? = nil

  private var cancellables: Set<AnyCancellable> = []

  private let backgroundDeliveryEnabled: ProtectedBox<Bool> = .init(value: false)
  let configuration: ProtectedBox<Configuration>

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
      VitalLogger.healthKit.error("Failed to perform automatic configuration: \(error, privacy: .public)")
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
      VitalLogger.healthKit.info("We weren't able to securely store Configuration: \(error, privacy: .public)")
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
      self.numberOfDaysToBackFill = min(numberOfDaysToBackFill, 90)
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
        .map(self.store.remapResource)
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
        .flatMap { $0.required + $0.optional }
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

    let task = Task(priority: .high) {
      /// Detect if we have ever had performed an initial sync.
      /// If we never did, start a background task and runs the initial sync first.
      /// This ensures that `syncData` is called on all VitalResources at least once.
      ///
      /// We would defer consuming `stream` until all the initial sync are completed.
      let unflaggedResources = resources.filter { storage.readFlag(for: $0.wrapped) == false }

      if unflaggedResources.isEmpty == false {
        VitalLogger.healthKit.info("[historical-bgtask] Started for \(unflaggedResources, privacy: .public)")

        let osBackgroundTask = ProtectedBox<UIBackgroundTaskIdentifier>()
        osBackgroundTask.start("vital-historical-stage", expiration: {})
        defer {
          osBackgroundTask.endIfNeeded()
          VitalLogger.healthKit.info("[historical-bgtask] Ended")
        }

        try await withTaskCancellationHandler {

          for resource in unflaggedResources {
            try Task.checkCancellation()
            await sync(resource)
          }

        } onCancel: { osBackgroundTask.endIfNeeded() }

      }

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

        VitalLogger.healthKit.info("[BackgroundDelivery] Dequeued payload for \(payload.sampleTypes, privacy: .public)")

        guard let first = payload.sampleTypes.first else {
          continue
        }

        /// This means we are trying to sync related samples, so let's convert it to a `VitalResource`
        let resource = store.remapResource(store.toVitalResource(first))
        await sync(resource)
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
          VitalLogger.healthKit.error("Failed to enable background delivery for type: \(sampleType.identifier, privacy: .public). Did you enable \"Background Delivery\" in Capabilities?")
          return
        }
        
        VitalLogger.healthKit.info("Successfully enabled background delivery for type: \(sampleType.identifier, privacy: .public)")
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
            VitalLogger.healthKit.error("Failed to background deliver for \(String(describing: sampleTypes), privacy: .public) with \(error, privacy: .public).")

            ///  We need a better way to handle if a failure happens here.
            return
          }

          VitalLogger.healthKit.info("[HealthKit] Notified changes in \(sampleTypes, privacy: .public)")

          // It appears that the iOS 15+ HKObserverQuery might pass us `HKSampleType`s that is
          // outside the conditions we specified via `descriptors`. Filter out any unsolicited types
          // before proceeding.
          let filteredSampleTypes = sampleTypes.intersection(typesToObserve)

          if filteredSampleTypes.isEmpty {
            handler()
          } else {
            let payload = BackgroundDeliveryPayload(
              sampleTypes: filteredSampleTypes,
              completion: { completion in
                if completion == .completed {
                  handler()
                }
              }
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
            VitalLogger.healthKit.error("Failed to background deliver for \(sampleType.identifier, privacy: .public).")
            
            ///  We need a better way to handle if a failure happens here.
            return
          }

          VitalLogger.healthKit.info("[HealthKit] Notified changes in \(sampleType, privacy: .public)")
          
          let payload = BackgroundDeliveryPayload(
            sampleTypes: Set([sampleType]),
            completion: { completion in
              if completion == .completed {
                handler()
              }
            }
          )
          continuation.yield(payload)
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
  
  private func calculateStage(
    resource: VitalResource,
    startDate: Date,
    endDate: Date
  ) -> TaggedPayload.Stage  {
    
    /// We don't keep a historical record for profile data
    if resource == .profile {
      return .daily
    }
    
    return storage.readFlag(for: resource) ? .daily : .historical(start: startDate, end: endDate)
  }
  
  public func syncData() {
    let resources = resourcesAskedForPermission(store: store)
    syncData(for: Array(resources))
  }
  
  public func syncData(for resources: [VitalResource]) {
    Task(priority: .high) {
      let remappedResources = Set(resources.map(self.store.remapResource(_:)))
      for resource in remappedResources {
        await sync(resource)
      }
      
      _status.send(.syncingCompleted)
    }
  }

  @available(*, deprecated, message: "Use `VitalClient.shared.signOut()`, which now resets both the Vital Core and Health SDKs.")
  public func cleanUp() async {
    await VitalClient.shared.signOut()
  }

  private func resetAutoSync() async {
    backgroundDeliveryTask?.task.cancel()
    backgroundDeliveryTask = nil
    backgroundDeliveryEnabled.set(value: false)

    await store.disableBackgroundDelivery()
  }
  
  private func sync(_ resource: RemappedVitalResource) async {
    guard self.pauseSynchronization == false else { return }

    let resource = resource.wrapped

    let configuration = await configuration.get()
    let startDate: Date = .dateAgo(days: configuration.numberOfDaysToBackFill)
    let endDate: Date = Date()
    
    let infix = ""
    let description = resource.logDescription

    VitalLogger.healthKit.info("Syncing HealthKit \(infix, privacy: .public): \(description, privacy: .public)")
    
    do {
      // Signal syncing (so the consumer can convey it to the user)
      _status.send(.syncing(resource))

      let stage = calculateStage(
        resource: resource,
        startDate: startDate,
        endDate: endDate
      )
      /// Make sure the user has a connected source set up
      try await vitalClient.checkConnectedSource(.appleHealthKit)

      // Sync sdk status
      let body: UserSDKSyncStateBody
      switch stage {
      case .daily:
        body = UserSDKSyncStateBody(stage: Stage.daily, tzinfo: TimeZone.current.identifier)
      case let .historical(start, end):
        body = UserSDKSyncStateBody(stage: Stage.historical, tzinfo: TimeZone.current.identifier, requestStartDate: start, requestEndDate: end)
      }
      let statusResponse = try await vitalClient.sdkStateSync(body)
      
      guard statusResponse.status == .active else {
        VitalLogger.healthKit.info("Skipping. Connected source is \(statusResponse.status.rawValue, privacy: .public)")
        _status.send(.nothingToSync(resource))
        return
      }
      
      let startDateInBounds = statusResponse.requestStartDate ?? startDate
      let endDateInBounds = statusResponse.requestEndDate ?? endDate
      
      // Fetch from HealthKit
      let (data, entitiesToStore): (ProcessedResourceData?, [StoredAnchor])
      
      (data, entitiesToStore) = try await store.readResource(
        resource,
        startDateInBounds,
        endDateInBounds,
        storage
      )

      guard let data = data, data.shouldSkipPost == false else {
        /// If there's no data, independently of the stage, we won't send it.
        /// Currently the server is returning 4XX when sending an empty payload.
        /// More context on VIT-2232.

        // TODO: We should post something anyway so that backend can emit a historical event.

        /// If it's historical, we store the entity and bailout
        if stage.isDaily == false {
          storage.storeFlag(for: resource)
          entitiesToStore.forEach(storage.store(entity:))
        }

        VitalLogger.healthKit.info("Skipping. No new data available \(infix, privacy: .public): \(description, privacy: .public)")
        _status.send(.nothingToSync(resource))

        return
      }
      
      if configuration.mode.isAutomatic {
        VitalLogger.healthKit.info(
          "Automatic Mode. Posting data for stage \(stage, privacy: .public) \(infix, privacy: .public): \(description, privacy: .public)"
        )
        
        let transformedData = transform(data: data, calendar: vitalCalendar)

        // Post data
        try await vitalClient.post(
          transformedData,
          stage,
          .appleHealthKit,
          /// We can't use `vitalCalendar` here. We want to send the user's timezone
          /// rather than UTC (which is what `vitalCalendar` is set to).
          TimeZone.current
        )
      } else {
        VitalLogger.healthKit.info(
          "Manual Mode. Skipping posting data for stage \(stage, privacy: .public) \(infix, privacy: .public): \(description, privacy: .public)"
        )
      }
      
      // This is used for calculating the stage (daily vs historical)
      storage.storeFlag(for: resource)
      
      // Save the anchor/date on a succesfull network call
      entitiesToStore.forEach(storage.store(entity:))
      
      VitalLogger.healthKit.info("Completed syncing \(infix, privacy: .public): \(description, privacy: .public)")
      
      // Signal success
      _status.send(.successSyncing(resource, data))
    }
    catch let error {
      // Signal failure
      VitalLogger.healthKit.error(
        "Failed syncing data \(infix, privacy: .public): \(description, privacy: .public). Error: \(error, privacy: .public)"
      )
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
    let dates: [Date] = (requirements.required + requirements.optional).map {
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
    let store = HKHealthStore()
    
    let (data, _): (ProcessedResourceData?, [StoredAnchor]) = try await VitalHealthKit.read(
      resource: resource,
      healthKitStore: store,
      typeToResource: VitalHealthKitStore.live.toVitalResource,
      vitalStorage: VitalHealthKitStorage(storage: .debug),
      startDate: startDate,
      endDate: endDate
    )

    if let data = data {
      return transform(data: data, calendar: vitalCalendar)
    }

    return nil
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

func transform(data: ProcessedResourceData, calendar: Calendar) -> ProcessedResourceData {
  switch data {
    case .summary(.activity):
      return data

    case let .summary(.workout(patch)):
      let workouts = patch.workouts.map { workout in
        WorkoutPatch.Workout(
          id: workout.id,
          startDate: workout.startDate,
          endDate: workout.endDate,
          movingTime: workout.movingTime,
          sourceBundle: workout.sourceBundle,
          productType: workout.productType,
          sport: workout.sport,
          calories: workout.calories,
          distance: workout.distance,
          ascentElevation: workout.ascentElevation,
          descentElevation: workout.descentElevation,
          heartRate: average(workout.heartRate, calendar: calendar),
          respiratoryRate: average(workout.respiratoryRate, calendar: calendar)
        )
      }
      
      return .summary(.workout(WorkoutPatch(workouts: workouts)))

    case let.summary(.sleep(patch)):
      let sleep = patch.sleep.map { sleep in
        SleepPatch.Sleep(
          id: sleep.id,
          startDate: sleep.startDate,
          endDate: sleep.endDate,
          sourceBundle: sleep.sourceBundle,
          productType: sleep.productType,
          heartRate: average(sleep.heartRate, calendar: calendar),
          restingHeartRate: average(sleep.restingHeartRate, calendar: calendar),
          heartRateVariability: average(sleep.heartRateVariability, calendar: calendar),
          oxygenSaturation: average(sleep.oxygenSaturation, calendar: calendar),
          respiratoryRate: average(sleep.respiratoryRate, calendar: calendar),
          sleepStages: sleep.sleepStages
        )
      }

      return .summary(.sleep(SleepPatch(sleep: sleep)))
      
    case .summary(.body), .summary(.profile):
      return data
      
    case let .timeSeries(.heartRate(samples)):
      let newSamples = average(samples, calendar: calendar)
      return .timeSeries(.heartRate(newSamples))
      
    case .timeSeries:
      return data
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
