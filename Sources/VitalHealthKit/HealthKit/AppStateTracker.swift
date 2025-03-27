import Foundation
import UIKit
import Combine
import VitalCore

final class AppStateTracker {
  static let shared = AppStateTracker()

  private let historyStoreUpdateQueue = DispatchQueue(
    label: "com.junction.AppStateTracker.historyStoreUpdateQueue",
    qos: .userInteractive
  )

  private let lock = NSLock()
  private var _state: AppState = AppState()
  private var onChange: ((AppState) -> Void)? = nil

  var state: AppState {
    lock.withLock { _state }
  }

  init() {
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(appDidFinishLaunching),
      name: UIApplication.didFinishLaunchingNotification,
      object: nil
    )

    NotificationCenter.default.addObserver(
      self,
      selector: #selector(appWillEnterForeground),
      name: UIApplication.willEnterForegroundNotification,
      object: nil
    )

    NotificationCenter.default.addObserver(
      self,
      selector: #selector(appDidEnterBackground),
      name: UIApplication.didEnterBackgroundNotification,
      object: nil
    )

    NotificationCenter.default.addObserver(
      self,
      selector: #selector(appWillTerminate),
      name: UIApplication.willTerminateNotification,
      object: nil
    )

    NotificationCenter.default.addObserver(
      self,
      selector: #selector(powerStateDidChange),
      name: NSNotification.Name.NSProcessInfoPowerStateDidChange,
      object: nil
    )

    NotificationCenter.default.addObserver(
      self,
      selector: #selector(significantTimeChange),
      name: UIApplication.significantTimeChangeNotification,
      object: nil
    )
  }

  func register(_ onChange: @escaping (AppState) -> Void) {
    lock.withLock { self.onChange = onChange }
  }

  @objc
  func appDidFinishLaunching() {
    // UIApplication.applicationState is always `.background` in this moment.
    // Schedule a check on the next runloop iteration.
    DispatchQueue.main.async {
      self.powerStateDidChange()
    }
  }

  @objc
  func appWillEnterForeground() {
    transition(to: .foreground)
  }

  @objc
  func appDidEnterBackground() {
    transition(to: .background)
  }

  @objc
  func powerStateDidChange() {
    let state = UIApplication.shared.applicationState
    transition(to: state == .background ? .background : .foreground)
  }

  func transition(to newStatus: AppState.Status) {
    var newState = AppState()
    newState.lowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
    newState.barRestricted = UIApplication.shared.backgroundRefreshStatus != .available
    newState.status = newStatus

    let (state, onChange) = lock.withLock {
      _state = newState
      return (_state, self.onChange)
    }

    VitalLogger.healthKit.info("\(state)", source: "AppState")

    onChange?(state)
    historyStoreUpdateQueue.async {
      UserHistoryStore.shared.record(TimeZone.current)
    }
  }

  @objc
  func appWillTerminate() {
    let (state, onChange) = lock.withLock {
      _state.status = .terminating
      return (_state, self.onChange)
    }

    VitalLogger.healthKit.info("\(state)", source: "AppState")

    onChange?(state)
  }

  @objc
  func significantTimeChange() {
    historyStoreUpdateQueue.async {
      UserHistoryStore.shared.record(TimeZone.current)
    }
  }
}

struct AppState {
  enum Status {
    case launching
    case foreground
    case background
    case terminating
  }

  var status: Status = .launching
  var lowPowerMode: Bool = false
  var barRestricted: Bool = false
}
