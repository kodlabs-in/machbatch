import ClusterCore
import Compatibility
import Config
import Foundation
import Persistence
import ResourceProbe

struct CLIApplication {
  private let paths: ApplicationPaths

  init(paths: ApplicationPaths = .resolve()) {
    self.paths = paths
  }

  func run(command: String, arguments: [String]) throws {
    if let slurmCommand = SlurmCommand(rawValue: command) {
      try CompatibilityManifest.current.validate(command: slurmCommand, arguments: arguments)
    }
    guard !printMetadataIfRequested(command: command, arguments: arguments) else { return }

    try dispatch(command: command, arguments: arguments)
  }

  private func dispatch(command: String, arguments: [String]) throws {
    switch command {
    case "sinfo": try printClusterInformation()
    case "sbatch": try submit(arguments)
    case "squeue": try printQueue()
    case "scancel": try cancel(arguments)
    case "sacct": try printAccounting(arguments)
    case "doctor": try printDiagnostics()
    case "machbatch": printVersion()
    default: throw CLIError.unsupportedCommand(command)
    }
  }

  private func printMetadataIfRequested(command: String, arguments: [String]) -> Bool {
    if arguments.contains("--version") {
      printVersion()
      return true
    }
    if arguments.contains("--help") {
      printHelp(command: command)
      return true
    }
    return false
  }

  private func printClusterInformation() throws {
    let host = try SystemResourceProbe().probe()
    let configuration = try DefaultClusterConfigurationBuilder().build(for: host)
    print(SinfoRenderer().render(configuration))
  }

  private func submit(_ arguments: [String]) throws {
    let source = try batchSource(from: arguments)
    let options = try BatchOptionResolver().resolve(script: source.script, commandLine: arguments)
    let store = try openStore()
    let submission = JobSubmission(
      name: options.jobName,
      user: NSUserName(),
      partition: options.partition,
      command: source.command,
      resources: Resources(cpuSlots: options.cpuSlots, memoryMiB: options.memoryMiB),
      wallTime: options.wallTime,
      workingDirectory: options.workingDirectory ?? FileManager.default.currentDirectoryPath,
      outputPath: options.outputPath,
      errorPath: options.errorPath,
      environment: options.environmentExport.resolve(from: ProcessInfo.processInfo.environment)
    )
    let job = try store.createJob(submission)
    let confirmation =
      options.parsable
      ? String(job.id.rawValue)
      : "Submitted batch job \(job.id.rawValue)"
    print(confirmation)
  }

  private func printQueue() throws {
    let activeStates = Set(JobState.allCases.filter { !$0.isTerminal })
    let jobs = try openStore().jobs().filter { activeStates.contains($0.state) }
    print(SqueueRenderer().render(jobs))
  }

  private func printAccounting(_ arguments: [String]) throws {
    let store = try openStore()
    let jobs = try accountingJobs(arguments: arguments, store: store)
    print(SacctRenderer().render(jobs))
  }

  private func printDiagnostics() throws {
    let store = try openStore()
    guard try store.integrityCheck() else { throw CLIError.databaseIntegrityCheckFailed }
    let host = try SystemResourceProbe().probe()
    print("database: ok")
    print("architecture: \(host.architecture.rawValue)")
    print("processors: \(host.activeProcessorCount)")
    print("memory: \(host.physicalMemoryMiB) MiB")
  }

  private func cancel(_ arguments: [String]) throws {
    guard let identifier = arguments.first(where: { !$0.hasPrefix("-") }),
      let rawID = Int64(identifier)
    else {
      throw CLIError.missingJobID
    }
    try openStore().transition(
      jobID: JobID(rawID),
      to: .cancelled,
      actor: NSUserName(),
      reason: "cancelled by user"
    )
  }

  private func accountingJobs(
    arguments: [String],
    store: SQLiteJobStore
  ) throws -> [JobRecord] {
    guard let identifier = optionValue(named: "--jobs", shortName: "-j", in: arguments) else {
      return try store.jobs()
    }
    guard let rawID = Int64(identifier) else { throw CLIError.invalidJobID(identifier) }
    return try store.job(id: JobID(rawID)).map { [$0] } ?? []
  }

  private func batchSource(from arguments: [String]) throws -> BatchSource {
    if let command = optionValue(named: "--wrap", shortName: nil, in: arguments) {
      return BatchSource(script: "", command: ["/bin/zsh", "-c", command])
    }
    guard let path = arguments.last(where: { !$0.hasPrefix("-") }),
      FileManager.default.fileExists(atPath: path)
    else {
      throw CLIError.missingScript
    }
    let script = try String(contentsOfFile: path, encoding: .utf8)
    let spoolURL = try spool(script)
    return BatchSource(script: script, command: try interpreterCommand(script, path: spoolURL.path))
  }

  private func spool(_ script: String) throws -> URL {
    try paths.prepare()
    let directory = paths.spoolDirectory.appendingPathComponent("scripts", isDirectory: true)
    try FileManager.default.createDirectory(
      at: directory,
      withIntermediateDirectories: true,
      attributes: [.posixPermissions: 0o700]
    )
    let destination = directory.appendingPathComponent("\(UUID().uuidString).sh")
    try Data(script.utf8).write(to: destination, options: .atomic)
    try FileManager.default.setAttributes(
      [.posixPermissions: 0o600], ofItemAtPath: destination.path)
    return destination
  }

  private func interpreterCommand(_ script: String, path: String) throws -> [String] {
    guard let firstLine = script.split(separator: "\n", maxSplits: 1).first,
      firstLine.hasPrefix("#!")
    else {
      throw CLIError.missingShebang
    }
    let interpreter = firstLine.dropFirst(2).split(whereSeparator: \.isWhitespace).map(String.init)
    guard !interpreter.isEmpty else { throw CLIError.missingShebang }
    return interpreter + [path]
  }

  private func optionValue(
    named longName: String,
    shortName: String?,
    in arguments: [String]
  ) -> String? {
    if let value = arguments.first(where: { $0.hasPrefix("\(longName)=") }) {
      return String(value.dropFirst(longName.count + 1))
    }
    let names = [longName, shortName].compactMap { $0 }
    guard let index = arguments.firstIndex(where: names.contains),
      arguments.indices.contains(index + 1)
    else {
      return nil
    }
    return arguments[index + 1]
  }

  private func openStore() throws -> SQLiteJobStore {
    try paths.prepare()
    let store = try SQLiteJobStore(path: paths.databaseURL.path)
    try store.migrate()
    return store
  }

  private func printVersion() {
    let profile = CompatibilityProfile.current
    print("\(profile.name) \(profile.releaseVersion) — \(profile.cliCompatibility)")
  }

  private func printHelp(command: String) {
    let options =
      CompatibilityManifest.current.commands
      .first(where: { $0.command.rawValue == command })?
      .options.sorted().joined(separator: ", ") ?? ""
    print("Usage: \(command) [OPTIONS]\nSupported options: \(options)")
  }
}

extension JobState {
  fileprivate var isTerminal: Bool {
    [.completed, .failed, .cancelled, .timeout, .nodeFail].contains(self)
  }
}

enum CLIError: Error, CustomStringConvertible {
  case databaseIntegrityCheckFailed
  case invalidJobID(String)
  case missingJobID
  case missingScript
  case missingShebang
  case unsupportedCommand(String)

  var description: String {
    switch self {
    case .databaseIntegrityCheckFailed: "database integrity check failed"
    case .invalidJobID(let value): "Invalid job id specified: \(value)"
    case .missingJobID: "No job identification provided"
    case .missingScript: "sbatch requires a script path or --wrap"
    case .missingShebang: "batch script requires a valid shebang"
    case .unsupportedCommand(let command): "unsupported command: \(command)"
    }
  }
}

private struct BatchSource {
  let script: String
  let command: [String]
}
