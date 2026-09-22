import ClusterCore

public struct BatchOptions: Equatable, Sendable {
  public let jobName: String
  public let partition: String
  public let cpuSlots: Int
  public let memoryMiB: Int64
  public let wallTime: WallTime
  public let parsable: Bool
  public let outputPath: String
  public let errorPath: String?
  public let workingDirectory: String?
  public let environmentExport: EnvironmentExport

  public init(
    jobName: String,
    partition: String,
    cpuSlots: Int,
    memoryMiB: Int64,
    wallTime: WallTime,
    parsable: Bool,
    outputPath: String = "slurm-%j.out",
    errorPath: String? = nil,
    workingDirectory: String? = nil,
    environmentExport: EnvironmentExport = EnvironmentExport()
  ) {
    self.jobName = jobName
    self.partition = partition
    self.cpuSlots = cpuSlots
    self.memoryMiB = memoryMiB
    self.wallTime = wallTime
    self.parsable = parsable
    self.outputPath = outputPath
    self.errorPath = errorPath
    self.workingDirectory = workingDirectory
    self.environmentExport = environmentExport
  }
}

public struct EnvironmentExport: Equatable, Sendable {
  public let inheritsSubmissionEnvironment: Bool
  public let requestedNames: Set<String>
  public let assignments: [String: String]

  public init(
    inheritsSubmissionEnvironment: Bool = true,
    requestedNames: Set<String> = [],
    assignments: [String: String] = [:]
  ) {
    self.inheritsSubmissionEnvironment = inheritsSubmissionEnvironment
    self.requestedNames = requestedNames
    self.assignments = assignments
  }

  public func resolve(from submissionEnvironment: [String: String]) -> [String: String] {
    var resolved = inheritsSubmissionEnvironment ? submissionEnvironment : [:]
    for name in requestedNames {
      resolved[name] = submissionEnvironment[name]
    }
    resolved.merge(assignments) { _, assigned in assigned }
    return resolved
  }
}

public struct BatchOptionResolver: Sendable {
  public init() {}

  public func resolve(script: String, commandLine: [String]) throws -> BatchOptions {
    let directiveArguments = try BatchDirectiveParser().parse(script)
    let directives = try ParsedOptions.parse(directiveArguments)
    let commandLineOptions = try ParsedOptions.parse(commandLine)
    let options = directives.merging(commandLineOptions)

    return BatchOptions(
      jobName: options.value(named: "job-name") ?? "wrap",
      partition: options.value(named: "partition") ?? "local",
      cpuSlots: try positiveInteger(options.value(named: "cpus-per-task"), default: 1),
      memoryMiB: try memory(options.value(named: "mem"), default: 128),
      wallTime: try wallTime(options.value(named: "time"), default: WallTime(seconds: 60)),
      parsable: options.flags.contains("parsable"),
      outputPath: options.value(named: "output") ?? "slurm-%j.out",
      errorPath: options.value(named: "error"),
      workingDirectory: options.value(named: "chdir"),
      environmentExport: try environmentExport(options.value(named: "export"))
    )
  }

  private func positiveInteger(_ value: String?, default defaultValue: Int) throws -> Int {
    guard let value else { return defaultValue }
    guard let parsed = Int(value), parsed > 0 else {
      throw BatchOptionError.invalidValue(value)
    }
    return parsed
  }

  private func memory(_ value: String?, default defaultValue: Int64) throws -> Int64 {
    guard let value else { return defaultValue }
    return try MemorySize.parse(value).mebibytes
  }

  private func wallTime(_ value: String?, default defaultValue: WallTime) throws -> WallTime {
    guard let value else { return defaultValue }
    return try WallTime.parse(value)
  }

  private func environmentExport(_ value: String?) throws -> EnvironmentExport {
    guard let value else { return EnvironmentExport() }
    var inheritsSubmissionEnvironment = false
    var requestedNames: Set<String> = []
    var assignments: [String: String] = [:]

    for component in value.split(separator: ",", omittingEmptySubsequences: false).map(String.init)
    {
      if component == "ALL" {
        inheritsSubmissionEnvironment = true
      } else if component == "NONE" || component == "NIL" {
        continue
      } else if let separator = component.firstIndex(of: "=") {
        let name = String(component[..<separator])
        guard !name.isEmpty else { throw BatchOptionError.invalidValue(value) }
        assignments[name] = String(component[component.index(after: separator)...])
      } else if !component.isEmpty {
        requestedNames.insert(component)
      } else {
        throw BatchOptionError.invalidValue(value)
      }
    }
    return EnvironmentExport(
      inheritsSubmissionEnvironment: inheritsSubmissionEnvironment,
      requestedNames: requestedNames,
      assignments: assignments
    )
  }
}

public enum BatchOptionError: Error, Equatable {
  case invalidValue(String)
  case missingValue(String)
  case unsupportedOption(String)
}

private struct ParsedOptions {
  var values: [String: String] = [:]
  var flags: Set<String> = []

  static func parse(_ arguments: [String]) throws -> ParsedOptions {
    var parsed = ParsedOptions()
    var index = 0

    while index < arguments.count {
      let token = arguments[index]
      guard token.hasPrefix("-") else {
        index += 1
        continue
      }
      let splitToken = token.split(separator: "=", maxSplits: 1).map(String.init)
      guard let specification = specifications[splitToken[0]] else {
        throw BatchOptionError.unsupportedOption(splitToken[0])
      }
      if specification.takesValue {
        let value = try optionValue(
          attachedValue: splitToken.count == 2 ? splitToken[1] : nil,
          arguments: arguments,
          optionIndex: index,
          optionName: splitToken[0]
        )
        parsed.values[specification.canonicalName] = value
        index += splitToken.count == 2 ? 1 : 2
      } else {
        parsed.flags.insert(specification.canonicalName)
        index += 1
      }
    }
    return parsed
  }

  func value(named name: String) -> String? {
    values[name]
  }

  func merging(_ overriding: ParsedOptions) -> ParsedOptions {
    var merged = self
    merged.values.merge(overriding.values) { _, newValue in newValue }
    merged.flags.formUnion(overriding.flags)
    return merged
  }

  private static func optionValue(
    attachedValue: String?,
    arguments: [String],
    optionIndex: Int,
    optionName: String
  ) throws -> String {
    if let attachedValue { return attachedValue }
    let valueIndex = optionIndex + 1
    guard arguments.indices.contains(valueIndex) else {
      throw BatchOptionError.missingValue(optionName)
    }
    return arguments[valueIndex]
  }

  private static let specifications: [String: OptionSpecification] = [
    "-J": OptionSpecification(canonicalName: "job-name"),
    "--job-name": OptionSpecification(canonicalName: "job-name"),
    "-p": OptionSpecification(canonicalName: "partition"),
    "--partition": OptionSpecification(canonicalName: "partition"),
    "-c": OptionSpecification(canonicalName: "cpus-per-task"),
    "--cpus-per-task": OptionSpecification(canonicalName: "cpus-per-task"),
    "--mem": OptionSpecification(canonicalName: "mem"),
    "-t": OptionSpecification(canonicalName: "time"),
    "--time": OptionSpecification(canonicalName: "time"),
    "--wrap": OptionSpecification(canonicalName: "wrap"),
    "-o": OptionSpecification(canonicalName: "output"),
    "--output": OptionSpecification(canonicalName: "output"),
    "-e": OptionSpecification(canonicalName: "error"),
    "--error": OptionSpecification(canonicalName: "error"),
    "-D": OptionSpecification(canonicalName: "chdir"),
    "--chdir": OptionSpecification(canonicalName: "chdir"),
    "--export": OptionSpecification(canonicalName: "export"),
    "--parsable": OptionSpecification(canonicalName: "parsable", takesValue: false),
  ]
}

private struct OptionSpecification {
  let canonicalName: String
  let takesValue: Bool

  init(canonicalName: String, takesValue: Bool = true) {
    self.canonicalName = canonicalName
    self.takesValue = takesValue
  }
}
