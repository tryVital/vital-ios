import HealthKit
import VitalCore

struct VitalHealthKitStore {
  var isHealthDataAvailable: () -> Bool
  
  var requestReadWriteAuthorization: ([VitalResource], [WritableVitalResource]) async throws -> Void
  
  var hasAskedForPermission: (VitalResource) -> Bool
  
  var toVitalResource: (HKSampleType) -> VitalResource
  
  var writeInput: (DataInput, Date, Date) async throws -> Void
  var readResource: (VitalResource, Date, Date, VitalHealthKitStorage) async throws -> (ProcessedResourceData?, [StoredAnchor])
  
  var enableBackgroundDelivery: (HKObjectType, HKUpdateFrequency, @escaping (Bool, Error?) -> Void) -> Void
  var disableBackgroundDelivery: () async -> Void
  
  var execute: (HKObserverQuery) -> Void
  var stop: (HKObserverQuery) -> Void
}

extension VitalHealthKitStore {
  static func sampleTypeToVitalResource(
    hasAskedForPermission: ((VitalResource) -> Bool),
    type: HKSampleType
  ) -> VitalResource {
    switch type {
      case
        HKQuantityType.quantityType(forIdentifier: .bodyMass)!,
        HKQuantityType.quantityType(forIdentifier: .bodyFatPercentage)!:
        
        /// If the user has explicitly asked for Body permissions, then it's the resource is Body
        if hasAskedForPermission(.body) {
          return .body
        } else {
          /// If the user has given permissions to a single permission in the past (e.g. weight) we should
          /// treat it as such
          return type.toIndividualResource
        }
        
      case HKQuantityType.quantityType(forIdentifier: .height)!:
        return .profile
        
      case HKSampleType.workoutType():
        return .workout
        
      case HKSampleType.categoryType(forIdentifier: .sleepAnalysis):
        return .sleep
        
      case
        HKSampleType.quantityType(forIdentifier: .activeEnergyBurned)!,
        HKSampleType.quantityType(forIdentifier: .basalEnergyBurned)!,
        HKSampleType.quantityType(forIdentifier: .stepCount)!,
        HKSampleType.quantityType(forIdentifier: .flightsClimbed)!,
        HKSampleType.quantityType(forIdentifier: .distanceWalkingRunning)!,
        HKSampleType.quantityType(forIdentifier: .vo2Max)!:
        
        if hasAskedForPermission(.activity) {
          return .activity
        } else {
          return type.toIndividualResource
        }
        
      case HKSampleType.quantityType(forIdentifier: .bloodGlucose)!:
        return .vitals(.glucose)
        
      case
        HKSampleType.quantityType(forIdentifier: .bloodPressureSystolic)!,
        HKSampleType.quantityType(forIdentifier: .bloodPressureDiastolic)!:
        return .vitals(.bloodPressure)
        
      case HKSampleType.quantityType(forIdentifier: .heartRate)!:
        return .vitals(.hearthRate)

      case HKSampleType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!:
        return .vitals(.heartRateVariability)
        
      case HKSampleType.quantityType(forIdentifier: .dietaryWater)!:
        return .nutrition(.water)

      case HKSampleType.quantityType(forIdentifier: .dietaryCaffeine)!:
        return .nutrition(.caffeine)

      case HKSampleType.categoryType(forIdentifier: .mindfulSession)!:
        return .vitals(.mindfulSession)

      default:
        fatalError("\(String(describing: type)) is not supported. This is a developer error")
    }
  }
  
  static var live: VitalHealthKitStore {
    let store = HKHealthStore()
    
    let hasAskedForPermission: (VitalResource) -> Bool = { resource in
      return toHealthKitTypes(resource: resource)
        .map { store.authorizationStatus(for: $0) != .notDetermined }
        .reduce(true, { $0 && $1})
    }
    
    let toVitalResource: (HKSampleType) -> VitalResource = { type in
      return sampleTypeToVitalResource(hasAskedForPermission: hasAskedForPermission, type: type)
    }
    
    return .init {
      HKHealthStore.isHealthDataAvailable()
    } requestReadWriteAuthorization: { readResources, writeResources in
      let readTypes = readResources.flatMap(toHealthKitTypes)
      let writeTypes: [HKSampleType] = writeResources
        .map(\.toResource)
        .flatMap(toHealthKitTypes)
        .compactMap { type in
          type as? HKSampleType
        }
      
      if #available(iOS 15.0, *) {
        try await store.requestAuthorization(toShare: Set(writeTypes), read: Set(readTypes))
      } else {
        try await store.__requestAuthorization(toShare: Set(writeTypes), read: Set(readTypes))
      }
      
    } hasAskedForPermission: { resource in
      return hasAskedForPermission(resource)
    } toVitalResource: { type in
      return toVitalResource(type)
    } writeInput: { (dataInput, startDate, endDate) in
      try await write(
        healthKitStore: store,
        dataInput: dataInput,
        startDate: startDate,
        endDate: endDate
      )
    } readResource: { (resource, startDate, endDate, storage) in
      try await read(
        resource: resource,
        healthKitStore: store,
        typeToResource: toVitalResource,
        vitalStorage: storage,
        startDate: startDate,
        endDate: endDate
      )
    } enableBackgroundDelivery: { (type, frequency, completion) in
      store.enableBackgroundDelivery(for: type, frequency: frequency, withCompletion: completion)
    } disableBackgroundDelivery: {
      try? await store.disableAllBackgroundDelivery()
    } execute: { query in
      store.execute(query)
    } stop: { query in
      store.stop(query)
    }
  }
  
  static var debug: VitalHealthKitStore {
    return .init {
      return true
    } requestReadWriteAuthorization: { _, _ in
      return
    } hasAskedForPermission: { _ in
      true
    } toVitalResource: { sampleType in
      return .sleep
    } writeInput: { (dataInput, startDate, endDate) in
      return
    } readResource: { _,_,_,_  in
      return (ProcessedResourceData.timeSeries(.glucose([])), [])
    } enableBackgroundDelivery: { _, _, _ in
      return
    } disableBackgroundDelivery: {
      return
    } execute: { _ in
      return
    } stop: { _ in
      return
    }
  }
}

struct VitalClientProtocol {
  var post: (ProcessedResourceData, TaggedPayload.Stage, Provider.Slug, TimeZone) async throws -> Void
  var checkConnectedSource: (Provider.Slug) async throws -> Void
}

extension VitalClientProtocol {
  static var live: VitalClientProtocol {
    .init { data, stage, provider, timeZone in
      switch data {
        case let .summary(summaryData):
          try await VitalClient.shared.summary.post(
            summaryData,
            stage: stage,
            provider: provider,
            timeZone: timeZone
          )
        case let .timeSeries(timeSeriesData):
          try await VitalClient.shared.timeSeries.post(
            timeSeriesData,
            stage: stage,
            provider: provider,
            timeZone: timeZone
          )
      }
    } checkConnectedSource: { provider in
      try await VitalClient.shared.checkConnectedSource(for: provider)
    }
  }
  
  static var debug: VitalClientProtocol {
    .init { _,_,_,_ in
      return ()
    } checkConnectedSource: { _ in
      return
    }
  }
}

enum VitalHealthKitError: Error {
  case anchoredQueryInconsistency
  case initialQueryAnchorLookupInconsistency
}

enum CheckInvalidatedStatisticsResult {
  /// Discovered more samples that would together invalidate summaries or timeseries in the specified time range.
  /// New anchor pointing to the last returned object is returned.
  case discoveredNewSamples(Range<Date>, HKQueryAnchor)

  /// No new samples were discovered, but the HKQueryAnchor should be moved.
  /// e.g. discovered only deleted objects
  case moveAnchor(HKQueryAnchor)

  /// No new sample to pull; keep last recorded anchor.
  case noNewSample

  var queryAnchor: HKQueryAnchor? {
    switch self {
    case let .moveAnchor(anchor):
      return anchor
    case let .discoveredNewSamples(_, anchor):
      return anchor
    case .noNewSample:
      return nil
    }
  }
}

struct StatisticsQueryDependencies {
  enum Granularity {
    case hourly
    case daily
  }

  /// Compute statistics at the specified granularity over the given time interval.
  ///
  /// Note that the time interval `Range<Date>` is end exclusive. This is because both the HealthKit query predicate
  /// and the resulting statistics use end-exclusive time intervals as well.
  var executeStatisticalQuery: (HKQuantityType, Range<Date>, Granularity) async throws -> [VitalStatistics]

  var getFirstAndLastSampleTime: (HKQuantityType, Range<Date>) async throws -> Range<Date>?

  /// Find the time range of statistics that is invalidated and needs to be recomputed, because
  /// newer samples have been inserted within the said range and hence potentially changing the
  /// statistical outcome.
  ///
  /// - parameters:
  ///   - type: The sample type to inspect
  ///   - minDate: The min datetime for samples to be considered in this process.
  ///   - fromAnchor: The query anchor which the sample matching should start from.
  var checkInvalidatedStatistics: (HKQuantityType, _ minDate: Date, _ fromAnchor: HKQueryAnchor) async throws -> CheckInvalidatedStatisticsResult

  /// Find the initial HKQueryAnchor for a historical backfill starting at the given datetime.
  ///
  /// - parameters:
  ///   - type: The sample type to inspect
  ///   - backfillInterval: The min datetime for samples to be considered in this process.
  var initialQueryAnchor: (HKQuantityType, _ backfillInterval: Range<Date>) async throws -> HKQueryAnchor?
  
  var isFirstTimeSycingType: (HKQuantityType) -> Bool
  var isLegacyType: (HKQuantityType) -> Bool
  
  var vitalAnchorsForType: (HKQuantityType) -> [VitalAnchor]
  var storedDate: (HKQuantityType) -> Date?
  var lastQueryAnchor: (HKQuantityType) -> HKQueryAnchor?

  var key: (HKQuantityType) -> String

  static var debug: StatisticsQueryDependencies {
    return .init { _, _, _ in
      fatalError()
    } getFirstAndLastSampleTime: { _, _ in
      fatalError()
    } checkInvalidatedStatistics: { _, _, _ in
      fatalError()
    } initialQueryAnchor: { _, _ in
      fatalError()
    } isFirstTimeSycingType: { _ in
      fatalError()
    } isLegacyType: { _ in
      fatalError()
    } vitalAnchorsForType: { _ in
      fatalError()
    } storedDate: { _ in
      fatalError()
    } lastQueryAnchor: { _ in
      fatalError()
    } key: { _ in
      fatalError()
    }
  }
  
  static func live(
    healthKitStore: HKHealthStore,
    vitalStorage: VitalHealthKitStorage
  ) -> StatisticsQueryDependencies {

    func mostRecentSampleStatistics(
      for type: HKQuantityType,
      queryInterval: Range<Date>
    ) async throws -> HKStatistics? {
      // If task is already cancelled, don't bother with starting the query.
      try Task.checkCancellation()

      return try await withCheckedThrowingContinuation { continuation in
        healthKitStore.execute(
          HKStatisticsQuery(
            quantityType: type,
            // start <= %K AND %K < end (end exclusive)
            quantitySamplePredicate: HKQuery.predicateForSamples(
              withStart: queryInterval.lowerBound,
              end: queryInterval.upperBound,
              options: []
            ),
            options: [.mostRecent]
          ) { query, statistics, error in
            guard let statistics = statistics else {
              precondition(error != nil, "HKStatisticsQuery returns neither a result nor an error.")

              switch (error as? HKError)?.code {
              case .errorNoData:
                continuation.resume(returning: nil)
              default:
                continuation.resume(throwing: error!)
              }

              return
            }

            continuation.resume(returning: statistics)
          }
        )
      }
    }

    return .init { type, queryInterval, granularity in

      // %@ <= %K AND %K < %@
      // Exclusive end as per Apple documentation
      // https://developer.apple.com/documentation/healthkit/hkquery/1614771-predicateforsampleswithstartdate#discussion
      let predicate = HKQuery.predicateForSamples(
        withStart: queryInterval.lowerBound,
        end: queryInterval.upperBound,
        options: []
      )

      let intervalComponents: DateComponents
      switch granularity {
      case .hourly:
        intervalComponents = DateComponents(hour: 1)
      case .daily:
        intervalComponents = DateComponents(day: 1)
      }

      // While we are interested in the contributing sources, we should not use
      // the `separateBySource` option, as we want HealthKit to provide
      // final statistics points that are merged from all data sources.
      //
      // We will issue a separate HKSourceQuery to lookup the contributing
      // sources.
      let query = HKStatisticsCollectionQuery(
        quantityType: type,
        quantitySamplePredicate: predicate,
        options: type.idealStatisticalQueryOptions,
        anchorDate: queryInterval.lowerBound,
        intervalComponents: intervalComponents
      )

      @Sendable func handle(
        _ query: HKStatisticsCollectionQuery,
        collection: HKStatisticsCollection?,
        error: Error?,
        continuation: CheckedContinuation<[VitalStatistics], Error>
      ) {
        healthKitStore.stop(query)

        guard let collection = collection else {
          precondition(error != nil, "HKStatisticsCollectionQuery returns neither a result set nor an error.")

          switch (error as? HKError)?.code {
          case .errorNoData:
            continuation.resume(returning: [])
          default:
            continuation.resume(throwing: error!)
          }

          return
        }

        // HKSourceQuery should report the set of sources of all the samples that
        // would have been matched by the HKStatisticsCollectionQuery.
        let sourceQuery = HKSourceQuery(sampleType: type, samplePredicate: predicate) { _, sources, _ in
          let sources = sources?.map { $0.bundleIdentifier } ?? []
          let values: [HKStatistics] = collection.statistics().filter { entry in
            // We perform a HKStatisticsCollectionQuery w/o strictStartDate and strictEndDate in
            // order to have aggregates matching numbers in the Health app.
            //
            // However, a caveat is that HealthKit can often return incomplete statistics point
            // outside the query interval we specified. While including samples astriding the
            // bounds would desirably contribute to stat points we are interested in, as a byproduct,
            // of the bucketing process (in our case, hourly buckets), HealthKit would also create
            // stat points from the unwanted portion of these samples.
            //
            // These unwanted stat points must be explicitly discarded, since they are not backed by
            // the complete set of samples within their representing time interval (as they are
            // rightfully excluded by the query interval we specified).
            //
            // Since both `queryInterval` and HKStatistics start..<end are end-exclusive, we only
            // need to test the start to filter out said unwanted entries.
            //
            // e.g., Given queryInterval = 23-02-03T01:00 ..< 23-02-04T01:00
            //        statistics[0]: 23-02-03T00:00 ..< 23-02-03T01:00 ❌
            //        statistics[1]: 23-02-03T01:00 ..< 23-02-03T02:00 ✅
            //        statistics[2]: 23-02-03T02:00 ..< 23-02-03T03:00 ✅
            //        ...
            //       statistics[23]: 23-02-03T23:00 ..< 23-02-04T00:00 ✅
            //       statistics[24]: 23-02-04T00:00 ..< 23-02-04T01:00 ✅
            //       statistics[25]: 23-02-04T01:00 ..< 23-02-04T02:00 ❌
            queryInterval.contains(entry.startDate)
          }

          do {
            let vitalStatistics = try values.map { statistics in
              try VitalStatistics(statistics: statistics, type: type, sources: sources)
            }

            continuation.resume(returning: vitalStatistics)
          } catch let error {
            continuation.resume(throwing: error)
          }
        }

        healthKitStore.execute(sourceQuery)
      }

      // If task is already cancelled, don't bother with starting the query.
      try Task.checkCancellation()

      return try await withCheckedThrowingContinuation { continuation in
        query.initialResultsHandler = { query, collection, error in
          handle(query, collection: collection, error: error, continuation: continuation)
        }

        healthKitStore.execute(query)
      }

    } getFirstAndLastSampleTime: { type, queryInterval in

      guard let statistics = try await mostRecentSampleStatistics(
        for: type,
        queryInterval: queryInterval
      ) else { return nil }

      // Unlike those from the HKStatisticsCollectionQuery, the single statistics from
      // HKStatisticsQuery uses the earliest start date and the latest end date from all the
      // samples matched by the predicate — this is the exact information we are looking for.
      //
      // https://developer.apple.com/documentation/healthkit/hkstatistics/1615351-startdate
      // https://developer.apple.com/documentation/healthkit/hkstatistics/1615067-enddate
      //
      // Clamp it to our queryInterval still.
      return (statistics.startDate ..< statistics.endDate)
          .clamped(to: queryInterval)

    } checkInvalidatedStatistics: { type, minDate, fromAnchor in

      func nextBatch(from anchor: HKQueryAnchor, predicate: NSPredicate, limit: Int) async throws -> CheckInvalidatedStatisticsResult {
        try Task.checkCancellation()
        return try await withCheckedThrowingContinuation { continuation in
          healthKitStore.execute(
            HKAnchoredObjectQuery(
              type: type,
              predicate: predicate,
              anchor: anchor,
              limit: limit
            ) { query, inserted, deleted, newAnchor, error in
              if let error = error {
                continuation.resume(throwing: error)
                return
              }

              // API promises non-nil value if error == nil.
              guard
                let inserted = inserted,
                let deleted = deleted
              else {
                continuation.resume(throwing: VitalHealthKitError.anchoredQueryInconsistency)
                return
              }

              // If both inserted & deleted are empty, logically speaking `newAnchor` would be nil
              // as well. Use the last known anchor in this case.
              let anchorToReturn = newAnchor ?? anchor

              // No sample is included, that means at this time there is nothing more to loop
              // through.
              guard inserted.isNotEmpty else {
                if deleted.isNotEmpty {
                  continuation.resume(returning: .moveAnchor(anchorToReturn))
                } else {
                  continuation.resume(returning: .noNewSample)
                }

                return
              }

              var minStart = Date.distantFuture
              var maxEnd = Date.distantPast

              // Double check the invariant;
              // we dont want to ever return distantPast ..< distantFuture.
              precondition(inserted.isNotEmpty)

              for sample in inserted {
                minStart = min(sample.startDate, minStart)
                maxEnd = max(sample.endDate, maxEnd)
              }

              continuation.resume(returning: .discoveredNewSamples(minStart ..< maxEnd, anchorToReturn))
            }
          )
        }
      }

      let minDatePredicate = HKQuery.predicateForSamples(withStart: minDate, end: nil, options: [])

      var lastAnchor: HKQueryAnchor = fromAnchor
      var mergedRange: Range<Date>?

      // Infinite loop to exhaust HKAnchoredObjectQuery (via nextBatch()) until it reports
      // `.noNewSample`.
      repeat {
        /// Iteratively look through every 500 inserted/deleted objects of the sample type,
        /// until the store runs out of any record (at this time). During the process, we
        /// track the minimum startDate and the maximum endDate of all inserted samples.
        ///
        /// The resulting time range union is the timeseries statistics points that have to be
        /// recomputed, since the inserted samples could potentially change the aggregate
        /// results (sum/min/max/avg/etc) and hence invalidating any previously sent ones.
        switch try await nextBatch(from: lastAnchor, predicate: minDatePredicate, limit: 500) {
        case let .discoveredNewSamples(timeRange, newAnchor):
          lastAnchor = newAnchor
          mergedRange = mergedRange.map { $0.union(timeRange) } ?? timeRange

        case let .moveAnchor(newAnchor):
          lastAnchor = newAnchor

        case .noNewSample:
          guard let mergedRange = mergedRange else {
            return fromAnchor != lastAnchor ? .moveAnchor(lastAnchor) : .noNewSample
          }
          return .discoveredNewSamples(mergedRange, lastAnchor)
        }

      } while true

    } initialQueryAnchor: { type, backfillStartDate in

      try Task.checkCancellation()

      // Process:
      // 1. Find the most recent sample using mostRecentSampleStatistics(2).
      // 2. Use the sample's time interval to find a valid HKQueryAnchor.
      //
      // Given that HKAnchoredObjectQuery is a de facto append-only sample insertion log
      // (rather than datetime based), any HKQueryAnchor we found is always guaranteed to be ordered
      // before any future samples being inserted, and hence no risk for "missing" new sample
      // in between this and a subsequent `checkInvalidatedStatistics(3)` call.

      guard
        let statistics = try await mostRecentSampleStatistics(
          for: type,
          queryInterval: backfillStartDate
        ),
        let mostRecentInterval = statistics.mostRecentQuantityDateInterval()
      else { return nil }

      return try await withCheckedThrowingContinuation { continuation in
        let predicate = HKQuery.predicateForSamples(
          withStart: mostRecentInterval.start,
          end: mostRecentInterval.end,
          options: []
        )
        healthKitStore.execute(
          HKAnchoredObjectQuery(
            type: type,
            predicate: predicate,
            anchor: nil,
            limit: HKObjectQueryNoLimit
          ) { _, _, _, anchor, error in
            if let error = error {
              continuation.resume(throwing: error)
              return
            }

            // We know for certain there is a most recent sample, so HKAnchoredObjectQuery should
            // be able to return an HKQueryAnchor for it. Throw an inconsistency error if this
            // invariant is violated.
            if let anchor = anchor {
              continuation.resume(returning: anchor)
            } else {
              continuation.resume(throwing: VitalHealthKitError.initialQueryAnchorLookupInconsistency)
            }
          }
        )
      }

    } isFirstTimeSycingType: { type in
      let key = String(describing: type.self)
      return vitalStorage.isFirstTimeSycingType(for: key)
      
    } isLegacyType: { type in
      let key = String(describing: type.self)
      return vitalStorage.isLegacyType(for: key)
      
    } vitalAnchorsForType: { type in
      let key = String(describing: type.self)
      return vitalStorage.read(key: key)?.vitalAnchors ?? []
      
    } storedDate: { type in
      let key = String(describing: type.self)
      return vitalStorage.read(key: key)?.date
      
    } lastQueryAnchor: { type in
      let key = String(describing: type.self)
      return vitalStorage.read(key: key)?.anchor

    } key: { type in
      return String(describing: type.self)
    }
  }
}
