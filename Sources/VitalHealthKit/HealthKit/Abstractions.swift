import HealthKit
@_spi(VitalSDKInternals) import VitalCore

struct RemappedVitalResource: Hashable {
  let wrapped: VitalResource
}

struct ReadOptions {
  var perDeviceActivityTS: Bool = false
  var embedTimeseries: Bool = false

  internal init(perDeviceActivityTS: Bool = false, embedTimeseries: Bool = false) {
    self.perDeviceActivityTS = perDeviceActivityTS
    self.embedTimeseries = embedTimeseries
  }
}

struct Predicates: @unchecked Sendable {
  let wrapped: [NSPredicate]

  init(_ predicates: [NSPredicate]) {
    self.wrapped = predicates
  }

  func withHeartRateZone(_ range: Range<Double>) -> Predicates {
    let unit = HKUnit.count().unitDivided(by: .minute())
    return Predicates(wrapped + [
      HKQuery.predicateForQuantitySamples(
        with: .greaterThanOrEqualTo,
        quantity: HKQuantity(unit: unit, doubleValue: range.lowerBound)
      ),
      HKQuery.predicateForQuantitySamples(
        with: .lessThan,
        quantity: HKQuantity(unit: unit, doubleValue: range.upperBound)
      ),
    ])
  }
}

struct VitalHealthKitStore {
  var isHealthDataAvailable: () -> Bool
  
  var requestReadWriteAuthorization: ([VitalResource], [WritableVitalResource]) async throws -> Void
  
  var hasAskedForPermission: (VitalResource) -> Bool
  
  var toVitalResource: (HKSampleType) -> VitalResource
  
  var writeInput: (DataInput, Date, Date) async throws -> Void
  var readResource: (RemappedVitalResource, SyncInstruction, VitalHealthKitStorage, ReadOptions) async throws -> (ProcessedResourceData?, [StoredAnchor])

  var enableBackgroundDelivery: (HKObjectType, HKUpdateFrequency, @escaping (Bool, Error?) -> Void) -> Void
  var disableBackgroundDelivery: () async -> Void
  
  var execute: (HKObserverQuery) -> Void
  var stop: (HKObserverQuery) -> Void
}

extension VitalHealthKitStore {
  static func remapResource(_ resource: VitalResource) -> RemappedVitalResource {
    // Remap individual resources to their composite version
    switch resource {
    case 
        .individual(.bodyFat),
        .individual(.weight):
      return RemappedVitalResource(wrapped: .body)

    case 
        .individual(.activeEnergyBurned),
        .individual(.basalEnergyBurned), 
        .individual(.distanceWalkingRunning),
        .individual(.exerciseTime), 
        .individual(.floorsClimbed),
        .individual(.steps),
        .individual(.vo2Max):
      return RemappedVitalResource(wrapped: .activity)

    default:
      break
    }

    // No remapping
    return RemappedVitalResource(wrapped: resource)
  }

  static func sampleTypeToVitalResource(type: HKSampleType) -> VitalResource {
    switch type {
      case
        HKQuantityType.quantityType(forIdentifier: .bodyMass)!,
        HKQuantityType.quantityType(forIdentifier: .bodyFatPercentage)!:

        return type.toIndividualResource
        
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
        HKSampleType.quantityType(forIdentifier: .vo2Max)!,
        HKSampleType.quantityType(forIdentifier: .appleExerciseTime)!:

        return type.toIndividualResource
        
      case HKSampleType.quantityType(forIdentifier: .bloodGlucose)!:
        return .vitals(.glucose)

      case HKSampleType.quantityType(forIdentifier: .oxygenSaturation)!:
        return .vitals(.bloodOxygen)
        
      case
        HKSampleType.quantityType(forIdentifier: .bloodPressureSystolic)!,
        HKSampleType.quantityType(forIdentifier: .bloodPressureDiastolic)!:
        return .vitals(.bloodPressure)
        
      case HKSampleType.quantityType(forIdentifier: .heartRate)!:
        return .vitals(.heartRate)

      case HKSampleType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!:
        return .vitals(.heartRateVariability)
        
      case HKSampleType.quantityType(forIdentifier: .dietaryWater)!:
        return .nutrition(.water)

      case HKSampleType.quantityType(forIdentifier: .dietaryCaffeine)!:
        return .nutrition(.caffeine)

      case HKSampleType.categoryType(forIdentifier: .mindfulSession)!:
        return .vitals(.mindfulSession)


    case
      HKCategoryType.categoryType(forIdentifier: .menstrualFlow)!,
      HKCategoryType.categoryType(forIdentifier: .cervicalMucusQuality)!,
      HKCategoryType.categoryType(forIdentifier: .intermenstrualBleeding)!,
      HKCategoryType.categoryType(forIdentifier: .ovulationTestResult)!,
      HKCategoryType.categoryType(forIdentifier: .sexualActivity)!,
      HKQuantityType.quantityType(forIdentifier: .basalBodyTemperature)!:
      return .menstrualCycle

    default:
      if #available(iOS 15.0, *) {
        switch type {
        case
          HKCategoryType.categoryType(forIdentifier: .contraceptive)!,
          HKCategoryType.categoryType(forIdentifier: .pregnancyTestResult)!,
          HKCategoryType.categoryType(forIdentifier: .progesteroneTestResult)!:
          return .menstrualCycle
        default:
          break
        }
      }


      if #available(iOS 16.0, *) {
        switch type {
        case
          HKCategoryType.categoryType(forIdentifier: .persistentIntermenstrualBleeding)!,
          HKCategoryType.categoryType(forIdentifier: .prolongedMenstrualPeriods)!,
          HKCategoryType.categoryType(forIdentifier: .irregularMenstrualCycles)!,
          HKCategoryType.categoryType(forIdentifier: .infrequentMenstrualCycles)!:
          return .menstrualCycle
        default:
          break
        }
      }

      fatalError("\(String(describing: type)) is not supported. This is a developer error")
    }
  }
  
  static var live: VitalHealthKitStore {
    let store = HKHealthStore()
    
    let hasAskedForPermission: (VitalResource) -> Bool = { resource in
      let requirements = toHealthKitTypes(resource: resource)
      return requirements.isResourceActive { store.authorizationStatus(for: $0) != .notDetermined }
    }
    
    let toVitalResource: (HKSampleType) -> VitalResource = { type in
      return sampleTypeToVitalResource(type: type)
    }
    
    return .init {
      HKHealthStore.isHealthDataAvailable()
    } requestReadWriteAuthorization: { readResources, writeResources in
      let readTypes: [HKObjectType] = readResources
        .map(toHealthKitTypes)
        .flatMap(\.allObjectTypes)

      let writeTypes: [HKSampleType] = writeResources
        .map(\.toResource)
        .map(toHealthKitTypes)
        .flatMap(\.allObjectTypes)
        .compactMap { $0 as? HKSampleType }

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
    } readResource: { (resource, instruction, storage, options) in
      try await read(
        resource: resource,
        healthKitStore: store,
        typeToResource: toVitalResource,
        vitalStorage: storage,
        instruction: instruction,
        options: options
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
    } readResource: { _,_,_, _  in
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
  var post: (ProcessedResourceData, TaggedPayload.Stage, Provider.Slug, TimeZone, Bool) async throws -> Void
  var checkConnectedSource: (Provider.Slug) async throws -> Void
  var sdkStateSync: (UserSDKSyncStateBody) async throws -> UserSDKSyncStateResponse
}

extension VitalClientProtocol {
  static var live: VitalClientProtocol {
    .init { data, stage, provider, timeZone, isFinalChunk in
      switch data {
        case let .summary(summaryData):
          try await VitalClient.shared.summary.post(
            summaryData,
            stage: stage,
            provider: provider,
            timeZone: timeZone,
            isFinalChunk: isFinalChunk
          )
        case let .timeSeries(timeSeriesData):
          try await VitalClient.shared.timeSeries.post(
            timeSeriesData,
            stage: stage,
            provider: provider,
            timeZone: timeZone,
            isFinalChunk: isFinalChunk
          )
      }
    } checkConnectedSource: { provider in
      try await VitalClient.shared.checkConnectedSource(for: provider)
    }
    sdkStateSync: {
      requestBody in
      try await VitalClient.shared.user.sdkStateSync(body: requestBody)
    }
  }
  
  static var debug: VitalClientProtocol {
    .init { _,_,_,_,_ in
      return ()
    } checkConnectedSource: { _ in
      return
    }
    sdkStateSync: {
      _ in
      return fatalError()
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
  var executeStatisticalQuery: (HKQuantityType, Range<Date>, Granularity, HKStatisticsOptions?) async throws -> [VitalStatistics]

  var executeSingleStatisticsQuery: (HKQuantityType, Range<Date>, HKStatisticsOptions, Predicates) async throws -> HKStatistics?

  var isFirstTimeSycingType: (HKQuantityType) -> Bool
  var isLegacyType: (HKQuantityType) -> Bool
  
  var vitalAnchorsForType: (HKQuantityType) -> [VitalAnchor]
  var storedDate: (HKQuantityType) -> Date?

  var key: (HKQuantityType) -> String

  static var debug: StatisticsQueryDependencies {
    return .init { _, _, _, _ in
      fatalError()
    } executeSingleStatisticsQuery: { _, _, _, _ in
      fatalError()
    } isFirstTimeSycingType: { _ in
      fatalError()
    } isLegacyType: { _ in
      fatalError()
    } vitalAnchorsForType: { _ in
      fatalError()
    } storedDate: { _ in
      fatalError()
    } key: { _ in
      fatalError()
    }
  }
  
  static func live(
    healthKitStore: HKHealthStore,
    vitalStorage: VitalHealthKitStorage
  ) -> StatisticsQueryDependencies {
    return .init { type, queryInterval, granularity, options in

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
        options: options ?? type.idealStatisticalQueryOptions,
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
            try VitalStatistics(statistics: statistics, type: type, options: options)
          }

          continuation.resume(returning: vitalStatistics)
        } catch let error {
          continuation.resume(throwing: error)
        }
      }

      // If task is already cancelled, don't bother with starting the query.
      try Task.checkCancellation()

      return try await withCheckedThrowingContinuation { continuation in
        query.initialResultsHandler = { query, collection, error in
          handle(query, collection: collection, error: error, continuation: continuation)
        }

        healthKitStore.execute(query)
      }

    } executeSingleStatisticsQuery: { type, date, options, predicates in

      // %@ <= %K AND %K < %@
      // Exclusive end as per Apple documentation
      // https://developer.apple.com/documentation/healthkit/hkquery/1614771-predicateforsampleswithstartdate#discussion
      let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
        HKQuery.predicateForSamples(
          withStart: date.lowerBound,
          end: date.upperBound,
          options: [.strictStartDate, .strictEndDate]
        )
      ] + predicates.wrapped)

      // If task is already cancelled, don't bother with starting the query.
      try Task.checkCancellation()

      return try await withCheckedThrowingContinuation { continuation in

        healthKitStore.execute(
          HKStatisticsQuery(
            quantityType: type,
            quantitySamplePredicate: predicate,
            options: options
          ) { _, statistics, error in
            guard let statistics = statistics else {
              guard let error = error else {
                continuation.resume(
                  throwing: VitalHealthKitClientError.healthKitInvalidState(
                    "HKStatisticsCollectionQuery returns neither a result set nor an error."
                  )
                )
                return
              }

              switch (error as? HKError)?.code {
              case .errorNoData:
                continuation.resume(with: .success(nil))
              default:
                continuation.resume(with: .failure(error))
              }

              return
            }

            continuation.resume(with: .success(statistics))
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
      
    } key: { type in
      return String(describing: type.self)
    }
  }
}
