import HealthKit

enum EntityToStore {
  case anchor(String, HKQueryAnchor)
  case date(Date)
}
