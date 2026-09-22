import ClusterCore
import Foundation

public struct ExecutionResult: Equatable, Sendable {
  public let exitStatus: Int32
  public let terminatingSignal: Int32?

  public init(exitStatus: Int32, terminatingSignal: Int32?) {
    self.exitStatus = exitStatus
    self.terminatingSignal = terminatingSignal
  }

  public var succeeded: Bool {
    exitStatus == 0 && terminatingSignal == nil
  }
}

public protocol JobExecuting {
  func execute(_ job: JobRecord) throws -> ExecutionResult
}

public struct ProcessJobExecutor: JobExecuting, Sendable {
  public init() {}

  public func execute(_ job: JobRecord) throws -> ExecutionResult {
    guard let executable = job.submission.command.first else {
      throw ProcessJobExecutorError.emptyCommand
    }

    let process = Process()
    process.executableURL = URL(fileURLWithPath: executable)
    process.arguments = Array(job.submission.command.dropFirst())
    process.environment = environment(for: job)
    try process.run()
    process.waitUntilExit()

    let signal = process.terminationReason == .uncaughtSignal ? process.terminationStatus : nil
    return ExecutionResult(exitStatus: process.terminationStatus, terminatingSignal: signal)
  }

  private func environment(for job: JobRecord) -> [String: String] {
    var environment = ProcessInfo.processInfo.environment
    environment["SLURM_JOB_ID"] = String(job.id.rawValue)
    environment["SLURM_JOB_NAME"] = job.submission.name
    environment["SLURM_JOB_USER"] = job.submission.user
    environment["SLURM_JOB_PARTITION"] = job.submission.partition
    environment["SLURM_CPUS_PER_TASK"] = String(job.submission.resources.cpuSlots)
    environment["SLURM_NTASKS"] = "1"
    return environment
  }
}

public enum ProcessJobExecutorError: Error, Equatable {
  case emptyCommand
}
