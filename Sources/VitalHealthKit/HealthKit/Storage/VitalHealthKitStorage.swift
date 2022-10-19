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
    
    storage.storeDate(entity.date, datePrefix)
    storage.store(data, anchorPrefix)
  }
  
  func read(key: String) -> StoredAnchor? {
    let anchorPrefix = anchorPrefix + key
    
    if let data = storage.read(anchorPrefix) {
      let anchor = try? NSKeyedUnarchiver.unarchivedObject(ofClass: HKQueryAnchor.self, from: data)
      return StoredAnchor(key: key, anchor: anchor, date: Date())
    }
    
    return nil
  }

  func remove(key: String) {
    storage.remove(key)
  }
}

struct StoredAnchor {
  let key: String
  let anchor: HKQueryAnchor
  let date : Date
  
  init?(key: String, anchor: HKQueryAnchor?, date: Date) {
    guard let anchor = anchor else {
      return nil
    }
    
    self.init(key: key, anchor: anchor, date: date)
  }
  
  init(key: String, anchor: HKQueryAnchor, date: Date) {
    self.key = key
    self.anchor = anchor
    self.date = date
  }
}
