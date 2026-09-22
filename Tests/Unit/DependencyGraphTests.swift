import ClusterCore
import XCTest

final class DependencyGraphTests: XCTestCase {
  func testRejectsDependencyCycle() throws {
    var graph = DependencyGraph()
    try graph.add(job: 2, dependsOn: [1])
    try graph.add(job: 3, dependsOn: [2])

    XCTAssertThrowsError(try graph.add(job: 1, dependsOn: [3]))
  }
}
