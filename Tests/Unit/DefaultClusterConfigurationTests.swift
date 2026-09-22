import ClusterCore
import Config
import XCTest

final class DefaultClusterConfigurationTests: XCTestCase {
  func testGeneratedNodesNeverExceedAllocatableHostCapacity() throws {
    let host = PhysicalHost(
      hostname: "test-mac",
      architecture: .arm64,
      activeProcessorCount: 8,
      physicalMemoryMiB: 16_384,
      operatingSystemVersion: "macOS"
    )

    let configuration = try DefaultClusterConfigurationBuilder().build(for: host)
    let nodeResources = configuration.nodes.map(\.resources).reduce(.zero, +)

    XCTAssertTrue(nodeResources.fits(within: configuration.allocatableResources))
    XCTAssertEqual(configuration.defaultPartition.name, "local")
    XCTAssertTrue((1...4).contains(configuration.nodes.count))
  }
}
