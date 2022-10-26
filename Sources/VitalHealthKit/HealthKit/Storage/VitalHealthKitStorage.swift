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

    guard
      let data = try? NSKeyedArchiver.archivedData(withRootObject: entity.anchor, requiringSecureCoding: true)
    else {
      return
    }
    
    if let date = entity.date {
      storage.storeDate(date, datePrefix)
    }
    
    storage.store(data, anchorPrefix)
  }
  
  func read(key: String) -> StoredAnchor? {
    let anchorPrefix = anchorPrefix + key
    let datePrefix = datePrefix + key

    
    var storeAnchor: StoredAnchor? = nil
    if let data = storage.read(anchorPrefix) {
      let anchor = try? NSKeyedUnarchiver.unarchivedObject(ofClass: HKQueryAnchor.self, from: data)
      storeAnchor = StoredAnchor(key: key, anchor: anchor, date: nil)
    }
    
    if let date = storage.readDate(datePrefix) {
      storeAnchor?.date = date
    }
    
    return storeAnchor
  }

  func remove(key: String) {
    storage.remove(key)
  }
}

struct StoredAnchor {
  var key: String
  var anchor: HKQueryAnchor
  var date : Date?
  
  init?(key: String, anchor: HKQueryAnchor?, date: Date?) {
    guard let anchor = anchor else {
      return nil
    }
    
    self.init(key: key, anchor: anchor, date: date)
  }
  
  init(key: String, anchor: HKQueryAnchor, date: Date?) {
    self.key = key
    self.anchor = anchor
    self.date = date
  }
}
