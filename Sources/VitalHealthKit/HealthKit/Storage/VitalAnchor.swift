import Foundation

struct VitalAnchor: Equatable, Codable, Hashable {
  var id: String
}

func anchorsToSend(old: [VitalAnchor], new: [VitalAnchor]) -> [VitalAnchor] {
  let oldSet = Set(old)
  let newSet = Set(new)
  
  return Array(newSet.subtracting(oldSet))
}

func anchorsToStore(old: [VitalAnchor], new: [VitalAnchor]) -> [VitalAnchor] {
  let oldSet = Set(old)
  let newSet = Set(new)
  
  return Array(newSet.union(oldSet))
}
