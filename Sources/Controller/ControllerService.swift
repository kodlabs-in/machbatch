import ClusterCore
import Executor
import Persistence
import Scheduler

public final class ControllerService {
  private let store: SQLiteJobStore
  private let scheduler: SchedulerEngine
  private let executor: any JobExecuting
  private var ledger: ResourceLedger

  public init(
    store: SQLiteJobStore,
    capacity: Resources,
    executor: any JobExecuting,
    scheduler: SchedulerEngine = SchedulerEngine()
  ) {
    self.store = store
    self.scheduler = scheduler
    self.executor = executor
    self.ledger = ResourceLedger(capacity: capacity)
  }

  public var allocatedResources: Resources {
    ledger.allocated
  }

  @discardableResult
  public func submit(_ submission: JobSubmission) throws -> JobRecord {
    try store.createJob(submission)
  }

  public func scheduleOnce() throws {
    let pendingRecords = try store.jobs(state: .pending)
    let selected = scheduler.select(
      from: pendingRecords.map(schedulableJob),
      available: availableResources
    )

    for pendingJob in selected {
      guard let record = pendingRecords.first(where: { $0.id == pendingJob.id }) else { continue }
      try run(record)
    }
  }

  public func recoverInterruptedJobs(liveJobIDs: Set<JobID>) throws {
    let recoverableStates: [JobState] = [
      .allocated, .starting, .running, .suspended, .completing,
    ]
    for state in recoverableStates {
      for job in try store.jobs(state: state) where !liveJobIDs.contains(job.id) {
        try store.transition(
          jobID: job.id,
          to: .nodeFail,
          reason: "supervisor unavailable during controller recovery"
        )
      }
    }
  }

  private var availableResources: Resources {
    Resources(
      cpuSlots: ledger.capacity.cpuSlots - ledger.allocated.cpuSlots,
      memoryMiB: ledger.capacity.memoryMiB - ledger.allocated.memoryMiB
    )
  }

  private func schedulableJob(_ record: JobRecord) -> PendingJob {
    PendingJob(
      id: record.id,
      resources: record.submission.resources,
      priority: 0,
      submissionOrder: record.id.rawValue
    )
  }

  private func run(_ job: JobRecord) throws {
    try ledger.reserve(job.submission.resources, for: job.id)
    defer { _ = try? ledger.release(for: job.id) }

    try store.transition(jobID: job.id, to: .allocated, reason: "resources reserved")
    try store.transition(jobID: job.id, to: .starting, reason: "launch requested")
    try store.transition(jobID: job.id, to: .running, reason: "process launched")

    do {
      let result = try executor.execute(job)
      try finish(jobID: job.id, result: result)
    } catch {
      try failRunningJob(jobID: job.id, reason: String(describing: error))
      throw error
    }
  }

  private func finish(jobID: JobID, result: ExecutionResult) throws {
    try store.transition(jobID: jobID, to: .completing, reason: "process exited")
    let finalState: JobState = result.succeeded ? .completed : .failed
    try store.transition(
      jobID: jobID,
      to: finalState,
      reason: "exit status \(result.exitStatus)"
    )
  }

  private func failRunningJob(jobID: JobID, reason: String) throws {
    try store.transition(jobID: jobID, to: .completing, reason: "launch failed: \(reason)")
    try store.transition(jobID: jobID, to: .failed, reason: reason)
  }
}
