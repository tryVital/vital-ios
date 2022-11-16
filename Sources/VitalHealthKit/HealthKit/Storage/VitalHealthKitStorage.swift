import HealthKit
import VitalCore

class VitalHealthKitStorage {
  
  private let anchorPrefix = "vital_anchor_"
  private let datePrefix = "vital_anchor_date_"

  private let flag = "vital_anchor_"

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
  
  func store(entity: StoredAnchor) {
    let anchorPrefix = anchorPrefix + entity.key
    let datePrefix = datePrefix + entity.key

    if let anchor = entity.anchor,
       let data = try? NSKeyedArchiver.archivedData(withRootObject: anchor, requiringSecureCoding: true)
    {
      storage.store(data, anchorPrefix)
    }
    
    if let date = entity.date {
      storage.storeDate(date, datePrefix)
    }
  }
  
  func read(key: String) -> StoredAnchor? {
    let anchorPrefix = anchorPrefix + key
    let datePrefix = datePrefix + key
    
    var storeAnchor: StoredAnchor = .init(key: key, anchor: nil, date: nil)
    
    if
      let data = storage.read(anchorPrefix),
      let anchor = try? NSKeyedUnarchiver.unarchivedObject(ofClass: HKQueryAnchor.self, from: data)
    {
      storeAnchor.anchor = anchor
    }
    
    if let date = storage.readDate(datePrefix) {
      storeAnchor.date = date
    }
    
    if storeAnchor.anchor == nil && storeAnchor.date == nil {
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
  var date : Date?
  
  init(key: String, anchor: HKQueryAnchor?, date: Date?) {
    self.key = key
    self.anchor = anchor
    self.date = date
  }
}
