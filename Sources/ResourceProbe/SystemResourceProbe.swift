import ClusterCore
import Foundation

public struct SystemResourceProbe: Sendable {
  public init() {}

  public func probe() throws -> PhysicalHost {
    let processInfo = ProcessInfo.processInfo
    return PhysicalHost(
      hostname: processInfo.hostName,
      architecture: architecture,
      activeProcessorCount: processInfo.activeProcessorCount,
      physicalMemoryMiB: Int64(processInfo.physicalMemory / 1_048_576),
      operatingSystemVersion: processInfo.operatingSystemVersionString
    )
  }

  private var architecture: HostArchitecture {
    #if arch(arm64)
      return .arm64
    #elseif arch(x86_64)
      return .intel
    #else
      #error("MachBatch supports only arm64 and x86_64")
    #endif
  }
}
