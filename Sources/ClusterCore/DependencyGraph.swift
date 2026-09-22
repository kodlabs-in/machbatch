public struct DependencyGraph: Sendable {
  private var dependencies: [JobID: Set<JobID>] = [:]

  public init() {}

  public mutating func add(job: JobID, dependsOn requiredJobs: Set<JobID>) throws {
    var proposedDependencies = dependencies
    proposedDependencies[job, default: []].formUnion(requiredJobs)

    for requiredJob in requiredJobs
    where Self.isReachable(from: requiredJob, to: job, in: proposedDependencies) {
      throw DependencyGraphError.cycle(job: job, dependency: requiredJob)
    }
    dependencies = proposedDependencies
  }

  private static func isReachable(
    from start: JobID,
    to target: JobID,
    in dependencies: [JobID: Set<JobID>]
  ) -> Bool {
    var pending = [start]
    var visited: Set<JobID> = []

    while let current = pending.popLast() {
      if current == target { return true }
      if visited.insert(current).inserted {
        pending.append(contentsOf: dependencies[current, default: []])
      }
    }
    return false
  }
}

public enum DependencyGraphError: Error, Equatable {
  case cycle(job: JobID, dependency: JobID)
}
