public enum HostArchitecture: String, Codable, Sendable {
  case intel = "x86_64"
  case arm64
}

public struct PhysicalHost: Equatable, Codable, Sendable {
  public let hostname: String
  public let architecture: HostArchitecture
  public let activeProcessorCount: Int
  public let physicalMemoryMiB: Int64
  public let operatingSystemVersion: String

  public init(
    hostname: String,
    architecture: HostArchitecture,
    activeProcessorCount: Int,
    physicalMemoryMiB: Int64,
    operatingSystemVersion: String
  ) {
    self.hostname = hostname
    self.architecture = architecture
    self.activeProcessorCount = activeProcessorCount
    self.physicalMemoryMiB = physicalMemoryMiB
    self.operatingSystemVersion = operatingSystemVersion
  }
}

public struct LogicalNode: Equatable, Codable, Sendable {
  public let name: String
  public let resources: Resources

  public init(name: String, resources: Resources) {
    self.name = name
    self.resources = resources
  }
}

public struct Partition: Equatable, Codable, Sendable {
  public let name: String
  public let nodeNames: [String]

  public init(name: String, nodeNames: [String]) {
    self.name = name
    self.nodeNames = nodeNames
  }
}

public struct ClusterConfiguration: Equatable, Codable, Sendable {
  public let host: PhysicalHost
  public let allocatableResources: Resources
  public let nodes: [LogicalNode]
  public let defaultPartition: Partition

  public init(
    host: PhysicalHost,
    allocatableResources: Resources,
    nodes: [LogicalNode],
    defaultPartition: Partition
  ) {
    self.host = host
    self.allocatableResources = allocatableResources
    self.nodes = nodes
    self.defaultPartition = defaultPartition
  }
}
