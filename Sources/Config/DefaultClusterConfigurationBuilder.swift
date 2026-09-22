import ClusterCore
import Foundation

public struct DefaultClusterSettings: Equatable, Sendable {
  public let cpuReserveFraction: Double
  public let minimumReservedCPUSlots: Int
  public let memoryReserveFraction: Double
  public let minimumNodeMemoryMiB: Int64
  public let maximumNodeCount: Int

  public init(
    cpuReserveFraction: Double = 0.15,
    minimumReservedCPUSlots: Int = 1,
    memoryReserveFraction: Double = 0.20,
    minimumNodeMemoryMiB: Int64 = 1_024,
    maximumNodeCount: Int = 4
  ) {
    self.cpuReserveFraction = cpuReserveFraction
    self.minimumReservedCPUSlots = minimumReservedCPUSlots
    self.memoryReserveFraction = memoryReserveFraction
    self.minimumNodeMemoryMiB = minimumNodeMemoryMiB
    self.maximumNodeCount = maximumNodeCount
  }
}

public struct DefaultClusterConfigurationBuilder: Sendable {
  private let settings: DefaultClusterSettings

  public init(settings: DefaultClusterSettings = DefaultClusterSettings()) {
    self.settings = settings
  }

  public func build(for host: PhysicalHost) throws -> ClusterConfiguration {
    let allocatable = try allocatableResources(for: host)
    let nodeCount = numberOfNodes(for: allocatable)
    let nodes = (0..<nodeCount).map {
      LogicalNode(
        name: "localhost\($0)",
        resources: resourcesForNode($0, count: nodeCount, total: allocatable)
      )
    }
    let partition = Partition(name: "local", nodeNames: nodes.map(\.name))
    return ClusterConfiguration(
      host: host,
      allocatableResources: allocatable,
      nodes: nodes,
      defaultPartition: partition
    )
  }

  private func allocatableResources(for host: PhysicalHost) throws -> Resources {
    guard host.activeProcessorCount > 1,
      host.physicalMemoryMiB >= settings.minimumNodeMemoryMiB
    else {
      throw DefaultClusterConfigurationError.insufficientPhysicalResources
    }

    let proportionalCPUReserve = Int(
      ceil(Double(host.activeProcessorCount) * settings.cpuReserveFraction)
    )
    let cpuReserve = max(settings.minimumReservedCPUSlots, proportionalCPUReserve)
    let memoryReserve = Int64(
      ceil(Double(host.physicalMemoryMiB) * settings.memoryReserveFraction)
    )
    return Resources(
      cpuSlots: max(1, host.activeProcessorCount - cpuReserve),
      memoryMiB: host.physicalMemoryMiB - memoryReserve
    )
  }

  private func numberOfNodes(for resources: Resources) -> Int {
    let memoryLimitedCount = Int(resources.memoryMiB / settings.minimumNodeMemoryMiB)
    return max(1, min(settings.maximumNodeCount, resources.cpuSlots, memoryLimitedCount))
  }

  private func resourcesForNode(_ index: Int, count: Int, total: Resources) -> Resources {
    let cpuSlots = total.cpuSlots / count + (index < total.cpuSlots % count ? 1 : 0)
    let memoryMiB =
      total.memoryMiB / Int64(count)
      + (Int64(index) < total.memoryMiB % Int64(count) ? 1 : 0)
    return Resources(cpuSlots: cpuSlots, memoryMiB: memoryMiB)
  }
}

public enum DefaultClusterConfigurationError: Error, Equatable {
  case insufficientPhysicalResources
}
