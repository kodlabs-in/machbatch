import Foundation

public struct JobSubmission: Equatable, Codable, Sendable {
  public let name: String
  public let user: String
  public let partition: String
  public let command: [String]
  public let resources: Resources
  public let wallTime: WallTime
  public let workingDirectory: String
  public let outputPath: String
  public let errorPath: String?
  public let environment: [String: String]

  public init(
    name: String,
    user: String,
    partition: String,
    command: [String],
    resources: Resources,
    wallTime: WallTime,
    workingDirectory: String = FileManager.default.currentDirectoryPath,
    outputPath: String = "slurm-%j.out",
    errorPath: String? = nil,
    environment: [String: String] = [:]
  ) {
    self.name = name
    self.user = user
    self.partition = partition
    self.command = command
    self.resources = resources
    self.wallTime = wallTime
    self.workingDirectory = workingDirectory
    self.outputPath = outputPath
    self.errorPath = errorPath
    self.environment = environment
  }
}

public struct JobRecord: Equatable, Codable, Sendable {
  public let id: JobID
  public let submission: JobSubmission
  public let state: JobState
  public let submittedAt: Date

  public init(
    id: JobID,
    submission: JobSubmission,
    state: JobState,
    submittedAt: Date
  ) {
    self.id = id
    self.submission = submission
    self.state = state
    self.submittedAt = submittedAt
  }
}
