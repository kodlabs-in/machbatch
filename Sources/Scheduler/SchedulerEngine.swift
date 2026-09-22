import ClusterCore

public struct PendingJob: Equatable, Sendable {
  public let id: JobID
  public let resources: Resources
  public let priority: Int64
  public let submissionOrder: Int64

  public init(
    id: JobID,
    resources: Resources,
    priority: Int64,
    submissionOrder: Int64
  ) {
    self.id = id
    self.resources = resources
    self.priority = priority
    self.submissionOrder = submissionOrder
  }
}

public struct SchedulerEngine: Sendable {
  public init() {}

  public func select(from jobs: [PendingJob], available: Resources) -> [PendingJob] {
    let orderedJobs = jobs.sorted(by: isHigherPriority)
    var selected: [PendingJob] = []
    var allocated = Resources.zero

    for job in orderedJobs {
      let proposedAllocation = allocated + job.resources
      guard proposedAllocation.fits(within: available) else { continue }
      selected.append(job)
      allocated = proposedAllocation
    }

    return selected
  }

  private func isHigherPriority(_ lhs: PendingJob, _ rhs: PendingJob) -> Bool {
    if lhs.priority != rhs.priority { return lhs.priority > rhs.priority }
    if lhs.submissionOrder != rhs.submissionOrder {
      return lhs.submissionOrder < rhs.submissionOrder
    }
    return lhs.id.rawValue < rhs.id.rawValue
  }
}
