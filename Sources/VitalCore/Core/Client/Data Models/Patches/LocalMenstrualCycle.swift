import Foundation

public struct LocalMenstrualCycle: Equatable, Encodable {
  public let sourceBundle: String
  public let cycle: MenstrualCycle

  public init(
    sourceBundle: String,
    cycle: MenstrualCycle
  ) {
    self.sourceBundle = sourceBundle
    self.cycle = cycle
  }
}

public struct MenstrualCyclePatch: Equatable, Encodable {
  public let cycles: [LocalMenstrualCycle]

  public init(cycles: [LocalMenstrualCycle]) {
    self.cycles = cycles
  }
}
