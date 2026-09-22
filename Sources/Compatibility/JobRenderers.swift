import ClusterCore

extension JobState {
  public var slurmAbbreviation: String {
    switch self {
    case .submitted, .validating, .pending, .allocated, .starting: "PD"
    case .running: "R"
    case .suspended: "S"
    case .completing: "CG"
    case .completed: "CD"
    case .failed: "F"
    case .cancelled: "CA"
    case .timeout: "TO"
    case .nodeFail: "NF"
    }
  }
}

public struct SqueueRenderer: Sendable {
  public init() {}

  public func render(_ jobs: [JobRecord]) -> String {
    let header = "JOBID PARTITION     NAME     USER ST       TIME  NODES NODELIST(REASON)"
    let rows = jobs.map(renderJob)
    return ([header] + rows).joined(separator: "\n")
  }

  private func renderJob(_ job: JobRecord) -> String {
    let reason = job.state == .pending ? "(Priority)" : "localhost0"
    return " \(job.id.rawValue) \(job.submission.partition) \(job.submission.name) "
      + "\(job.submission.user) \(job.state.slurmAbbreviation) 0:00 1 \(reason)"
  }
}

public struct SacctRenderer: Sendable {
  public init() {}

  public func render(_ jobs: [JobRecord]) -> String {
    let header = "JobID           JobName  Partition    Account  AllocCPUS      State ExitCode"
    let rows = jobs.map(renderJob)
    return ([header] + rows).joined(separator: "\n")
  }

  private func renderJob(_ job: JobRecord) -> String {
    "\(job.id.rawValue) \(job.submission.name) \(job.submission.partition) "
      + "(null) \(job.submission.resources.cpuSlots) \(job.state.rawValue) 0:0"
  }
}
