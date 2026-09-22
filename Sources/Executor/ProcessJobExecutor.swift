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
    process.currentDirectoryURL = URL(fileURLWithPath: job.submission.workingDirectory)
    let handles = try outputHandles(for: job)
    defer { handles.close() }
    process.standardOutput = handles.output
    process.standardError = handles.error ?? handles.output
    try process.run()
    process.waitUntilExit()

    let signal = process.terminationReason == .uncaughtSignal ? process.terminationStatus : nil
    return ExecutionResult(exitStatus: process.terminationStatus, terminatingSignal: signal)
  }

  private func environment(for job: JobRecord) -> [String: String] {
    var environment = job.submission.environment
    environment["SLURM_JOB_ID"] = String(job.id.rawValue)
    environment["SLURM_JOB_NAME"] = job.submission.name
    environment["SLURM_JOB_USER"] = job.submission.user
    environment["SLURM_JOB_PARTITION"] = job.submission.partition
    environment["SLURM_CPUS_PER_TASK"] = String(job.submission.resources.cpuSlots)
    environment["SLURM_NTASKS"] = "1"
    return environment
  }

  private func outputHandles(for job: JobRecord) throws -> OutputHandles {
    let output = try openOutput(
      pattern: job.submission.outputPath,
      job: job
    )
    guard let errorPath = job.submission.errorPath else {
      return OutputHandles(output: output, error: nil)
    }
    return OutputHandles(
      output: output,
      error: try openOutput(pattern: errorPath, job: job)
    )
  }

  private func openOutput(pattern: String, job: JobRecord) throws -> FileHandle {
    let path = expandedPath(pattern, for: job)
    let url = resolvedURL(path, relativeTo: job.submission.workingDirectory)
    try FileManager.default.createDirectory(
      at: url.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    _ = FileManager.default.createFile(
      atPath: url.path,
      contents: nil,
      attributes: [.posixPermissions: 0o600]
    )
    let handle = try FileHandle(forWritingTo: url)
    try handle.truncate(atOffset: 0)
    return handle
  }

  private func expandedPath(_ pattern: String, for job: JobRecord) -> String {
    pattern
      .replacingOccurrences(of: "%j", with: String(job.id.rawValue))
      .replacingOccurrences(of: "%x", with: job.submission.name)
      .replacingOccurrences(of: "%u", with: job.submission.user)
      .replacingOccurrences(of: "%p", with: job.submission.partition)
  }

  private func resolvedURL(_ path: String, relativeTo workingDirectory: String) -> URL {
    guard !NSString(string: path).isAbsolutePath else {
      return URL(fileURLWithPath: path)
    }
    return URL(fileURLWithPath: workingDirectory).appendingPathComponent(path)
  }
}

public enum ProcessJobExecutorError: Error, Equatable {
  case emptyCommand
}

private struct OutputHandles {
  let output: FileHandle
  let error: FileHandle?

  func close() {
    try? output.close()
    try? error?.close()
  }
}
