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
    if arguments.contains("--version") {
      printVersion()
      return
    }

    switch command {
    case "sinfo": try printClusterInformation()
    case "sbatch": try submit(arguments)
    case "squeue": try printQueue()
    case "scancel": try cancel(arguments)
    case "sacct": try printAccounting(arguments)
    case "machbatch": printVersion()
    default: throw CLIError.unsupportedCommand(command)
    }
  }

  private func printClusterInformation() throws {
    let host = try SystemResourceProbe().probe()
    let configuration = try DefaultClusterConfigurationBuilder().build(for: host)
    print(SinfoRenderer().render(configuration))
  }

  private func submit(_ arguments: [String]) throws {
    let command = try wrappedCommand(from: arguments)
    let store = try openStore()
    let submission = JobSubmission(
      name: "wrap",
      user: NSUserName(),
      partition: "local",
      command: ["/bin/zsh", "-c", command],
      resources: Resources(cpuSlots: 1, memoryMiB: 128),
      wallTime: WallTime(seconds: 60)
    )
    let job = try store.createJob(submission)
    print("Submitted batch job \(job.id.rawValue)")
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

  private func wrappedCommand(from arguments: [String]) throws -> String {
    guard let command = optionValue(named: "--wrap", shortName: nil, in: arguments) else {
      throw CLIError.missingWrapCommand
    }
    return command
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
    print("\(profile.name) — \(profile.cliCompatibility)")
  }
}

extension JobState {
  fileprivate var isTerminal: Bool {
    [.completed, .failed, .cancelled, .timeout, .nodeFail].contains(self)
  }
}

enum CLIError: Error, CustomStringConvertible {
  case invalidJobID(String)
  case missingJobID
  case missingWrapCommand
  case unsupportedCommand(String)

  var description: String {
    switch self {
    case .invalidJobID(let value): "Invalid job id specified: \(value)"
    case .missingJobID: "No job identification provided"
    case .missingWrapCommand: "sbatch requires --wrap in this build"
    case .unsupportedCommand(let command): "unsupported command: \(command)"
    }
  }
}
