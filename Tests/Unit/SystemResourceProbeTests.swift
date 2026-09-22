import ResourceProbe
import XCTest

final class SystemResourceProbeTests: XCTestCase {
  func testReportsSupportedArchitectureAndPositiveCapacity() throws {
    let host = try SystemResourceProbe().probe()

    XCTAssertTrue(["arm64", "x86_64"].contains(host.architecture.rawValue))
    XCTAssertGreaterThan(host.activeProcessorCount, 0)
    XCTAssertGreaterThan(host.physicalMemoryMiB, 0)
  }
}
