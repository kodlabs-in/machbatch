public struct JobID: Hashable, Codable, Sendable, ExpressibleByIntegerLiteral {
  public let rawValue: Int64

  public init(_ rawValue: Int64) {
    self.rawValue = rawValue
  }

  public init(integerLiteral value: Int64) {
    self.init(value)
  }
}

public struct Resources: Equatable, Codable, Sendable {
  public let cpuSlots: Int
  public let memoryMiB: Int64

  public init(cpuSlots: Int, memoryMiB: Int64) {
    self.cpuSlots = cpuSlots
    self.memoryMiB = memoryMiB
  }

  public static let zero = Resources(cpuSlots: 0, memoryMiB: 0)

  public static func + (lhs: Resources, rhs: Resources) -> Resources {
    Resources(
      cpuSlots: lhs.cpuSlots + rhs.cpuSlots,
      memoryMiB: lhs.memoryMiB + rhs.memoryMiB
    )
  }

  public func fits(within capacity: Resources) -> Bool {
    cpuSlots <= capacity.cpuSlots && memoryMiB <= capacity.memoryMiB
  }
}

public struct ResourceLedger: Sendable {
  public let capacity: Resources
  private var reservations: [JobID: Resources]

  public init(capacity: Resources) {
    self.capacity = capacity
    reservations = [:]
  }

  public var allocated: Resources {
    reservations.values.reduce(.zero, +)
  }

  public mutating func reserve(_ resources: Resources, for jobID: JobID) throws {
    guard reservations[jobID] == nil else {
      throw ResourceLedgerError.duplicateReservation(jobID)
    }

    guard (allocated + resources).fits(within: capacity) else {
      throw ResourceLedgerError.insufficientCapacity
    }

    reservations[jobID] = resources
  }

  @discardableResult
  public mutating func release(for jobID: JobID) throws -> Resources {
    guard let resources = reservations.removeValue(forKey: jobID) else {
      throw ResourceLedgerError.missingReservation(jobID)
    }
    return resources
  }
}

public enum ResourceLedgerError: Error, Equatable {
  case duplicateReservation(JobID)
  case insufficientCapacity
  case missingReservation(JobID)
}
