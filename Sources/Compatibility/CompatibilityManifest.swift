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
      contract(.sinfo, helpAndVersion),
      contract(.squeue, helpAndVersion),
      contract(
        .sbatch,
        helpAndVersion.union([
          "--wrap", "-J", "--job-name", "-p", "--partition", "-c", "--cpus-per-task", "--mem",
          "-t", "--time", "-o", "--output", "-e", "--error", "-D", "--chdir", "--export",
          "--parsable",
        ])
      ),
      contract(.srun, helpAndVersion),
      contract(.salloc, helpAndVersion),
      contract(.scancel, helpAndVersion),
      contract(.sacct, helpAndVersion.union(["-j", "--jobs"])),
      contract(.sstat, helpAndVersion),
      contract(.sprio, helpAndVersion),
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
}
