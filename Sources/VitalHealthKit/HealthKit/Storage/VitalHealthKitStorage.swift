import HealthKit
import VitalCore

class VitalHealthKitStorage {

  private let anchorPrefix = "vital_anchor_"
  private let anchorsPrefix = "vital_anchors_"

  private let datePrefix = "vital_anchor_date_"

  private let flag = "vital_anchor_"

  private let initialSyncDone = "initial_sync_done"

  private let storage: VitalBackStorage
  
  init(storage: VitalBackStorage) {
    self.storage = storage
  }
  
  func storeFlag(for resource: VitalResource) {
    storage.flagResource(resource)
  }
  
  func readFlag(for resource: VitalResource) -> Bool {
    return storage.isResourceFlagged(resource)
  }

  func setCompletedInitialSync() {
    storage.store(Data([0x01]), initialSyncDone)
  }

  func hasCompletedInitalSync() -> Bool {
    return storage.read(initialSyncDone) == Data([0x01])
  }
  
  func isLegacyType(for key: String) -> Bool {
    let anchor = self.read(key: key)
    return anchor?.vitalAnchors == nil && (anchor?.date != nil || anchor?.anchor != nil)
  }
  
  func isFirstTimeSycingType(for key: String) -> Bool {
    let anchor = self.read(key: key)
    return anchor?.vitalAnchors == nil && anchor?.date == nil && anchor?.anchor == nil
  }
  
  func store(entity: StoredAnchor) {
    let anchorPrefix = anchorPrefix + entity.key
    let datePrefix = datePrefix + entity.key
    let anchorsPrefix = anchorsPrefix + entity.key

    if let anchor = entity.anchor,
       let data = try? NSKeyedArchiver.archivedData(withRootObject: anchor, requiringSecureCoding: true)
    {
      storage.store(data, anchorPrefix)
    }
    
    if
      let anchors = entity.vitalAnchors,
      let data = try? JSONEncoder().encode(anchors)
    {
      storage.store(data, anchorsPrefix)
    }
    
    if let date = entity.date {
      storage.storeDate(date, datePrefix)
    }
  }
  
  func read(key: String) -> StoredAnchor? {
    let anchorPrefix = anchorPrefix + key
    let datePrefix = datePrefix + key
    let anchorsPrefix = anchorsPrefix + key

    var storeAnchor: StoredAnchor = .init(key: key, anchor: nil, date: nil, vitalAnchors: nil)
    
    if
      let data = storage.read(anchorPrefix),
      let anchor = try? NSKeyedUnarchiver.unarchivedObject(ofClass: HKQueryAnchor.self, from: data)
    {
      storeAnchor.anchor = anchor
    }
    
    if let date = storage.readDate(datePrefix) {
      storeAnchor.date = date
    }
    
    if
      let data = storage.read(anchorsPrefix),
      let anchors = try? JSONDecoder().decode([VitalAnchor].self, from: data)
    {
      storeAnchor.vitalAnchors = anchors
    }
    
    if storeAnchor.anchor == nil && storeAnchor.date == nil && storeAnchor.vitalAnchors == nil {
      return nil
    }
    
    return storeAnchor
  }

  func remove(key: String) {
    storage.remove(key)
  }
}

struct StoredAnchor {
  var key: String
  var anchor: HKQueryAnchor?

  /// Used by the day summary process to determine when a summary was last computed.
  var date : Date?
  
  /// New approach (2.0)
  var vitalAnchors: [VitalAnchor]?
  
  init(key: String, anchor: HKQueryAnchor?, date: Date?, vitalAnchors: [VitalAnchor]?) {
    self.key = key
    self.anchor = anchor
    self.date = date
    self.vitalAnchors = vitalAnchors
  }
}
