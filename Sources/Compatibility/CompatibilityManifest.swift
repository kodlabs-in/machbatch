public enum SlurmCommand: String, CaseIterable, Codable, Sendable {
  case sinfo
  case squeue
  case sbatch
  case srun
  case salloc
  case scancel
  case sacct
  case sstat
  case sprio
  case scontrol
  case sacctmgr
}

public struct CommandCompatibility: Equatable, Codable, Sendable {
  public let command: SlurmCommand
  public let options: Set<String>

  public init(command: SlurmCommand, options: Set<String>) {
    self.command = command
    self.options = options
  }
}

public struct CompatibilityManifest: Equatable, Codable, Sendable {
  public let referenceVersion: String
  public let commands: [CommandCompatibility]
  public let intentionalDivergences: [String]

  public init(
    referenceVersion: String,
    commands: [CommandCompatibility],
    intentionalDivergences: [String]
  ) {
    self.referenceVersion = referenceVersion
    self.commands = commands
    self.intentionalDivergences = intentionalDivergences
  }

  public func validate(command: SlurmCommand, arguments: [String]) throws {
    guard let contract = commands.first(where: { $0.command == command }) else {
      throw CompatibilityManifestError.unsupportedCommand(command.rawValue)
    }

    for argument in arguments where argument.hasPrefix("-") {
      let option = String(argument.split(separator: "=", maxSplits: 1)[0])
      guard contract.options.contains(option) else {
        throw CompatibilityManifestError.unsupportedOption(command: command, option: option)
      }
    }
  }

  public static let current = CompatibilityManifest(
    referenceVersion: "26.05.4",
    commands: [
      contract(.sinfo, sinfoOptions),
      contract(.squeue, squeueOptions),
      contract(.sbatch, sbatchOptions),
      contract(.srun, commonAllocationOptions.union(srunOptions)),
      contract(.salloc, commonAllocationOptions.union(sallocOptions)),
      contract(.scancel, scancelOptions),
      contract(.sacct, sacctOptions),
      contract(.sstat, sstatOptions),
      contract(.sprio, sprioOptions),
      contract(.scontrol, helpAndVersion),
      contract(.sacctmgr, helpAndVersion),
    ],
    intentionalDivergences: [
      "--version identifies MachBatch as Slurm 26.05.4 CLI-compatible",
      "macOS process limits do not claim Linux cgroup-grade containment",
      "V1 schedules CPU and memory only",
    ]
  )
}

public enum CompatibilityManifestError: Error, Equatable {
  case unsupportedCommand(String)
  case unsupportedOption(command: SlurmCommand, option: String)
}

extension CompatibilityManifest {
  fileprivate static func contract(
    _ command: SlurmCommand,
    _ options: Set<String>
  ) -> CommandCompatibility {
    CommandCompatibility(command: command, options: options)
  }

  fileprivate static let helpAndVersion: Set<String> = ["--help", "--version"]
  fileprivate static let commonAllocationOptions: Set<String> = [
    "-J", "--job-name", "-p", "--partition", "-N", "--nodes", "-n", "--ntasks", "-c",
    "--cpus-per-task", "--mem", "--mem-per-cpu", "-t", "--time", "-o", "--output", "-e",
    "--error", "-D", "--chdir", "--export", "--array", "--dependency", "--begin", "--nice",
    "--qos", "-A", "--account", "-C", "--constraint", "--exclusive", "--help", "--version",
  ]
  fileprivate static let sinfoOptions: Set<String> = [
    "-a", "--all", "-h", "--noheader", "-l", "--long", "-N", "--Node", "-n", "--nodes", "-p",
    "--partition", "-o", "--format", "-t", "--states", "--help", "--version",
  ]
  fileprivate static let squeueOptions: Set<String> = [
    "-a", "--all", "-h", "--noheader", "-j", "--jobs", "-n", "--name", "-p", "--partition", "-u",
    "--user", "-t", "--states", "-o", "--format", "-S", "--start", "--sort", "--steps", "--help",
    "--version",
  ]
  fileprivate static let sbatchOptions = commonAllocationOptions.union([
    "--requeue", "--no-requeue", "--wrap", "--parsable", "--wait", "--test-only",
  ])
  fileprivate static let srunOptions: Set<String> = [
    "--pty", "-l", "--label", "--overlap", "--kill-on-bad-exit", "--input",
  ]
  fileprivate static let sallocOptions: Set<String> = ["--no-shell", "--quiet", "--verbose"]
  fileprivate static let scancelOptions: Set<String> = [
    "--signal", "--batch", "--full", "--name", "--partition", "--state", "--user", "--quiet",
    "--verbose", "--help", "--version",
  ]
  fileprivate static let sacctOptions: Set<String> = [
    "-j", "--jobs", "-S", "--starttime", "-E", "--endtime", "-u", "--user", "-a", "--allusers",
    "-X",
    "--allocations", "--state", "--name", "--format", "-n", "--noheader", "-p", "--parsable", "-P",
    "--parsable2", "--units", "--help", "--version",
  ]
  fileprivate static let sstatOptions: Set<String> = [
    "-j", "--jobs", "-a", "--allsteps", "--format", "-n", "--noheader", "-p", "--parsable", "-P",
    "--parsable2", "--help", "--version",
  ]
  fileprivate static let sprioOptions: Set<String> = [
    "-j", "--jobs", "-u", "--user", "-l", "--long", "-o", "--format", "-n", "--noheader", "-w",
    "--weights", "--help", "--version",
  ]
}
