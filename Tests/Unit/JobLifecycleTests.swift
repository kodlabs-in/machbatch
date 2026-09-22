import ClusterCore
import XCTest

final class JobLifecycleTests: XCTestCase {
  func testRejectsInvalidTransitionWithoutChangingState() throws {
    var lifecycle = JobLifecycle(initialState: .submitted)
    try lifecycle.transition(to: .validating)
    try lifecycle.transition(to: .pending)

    XCTAssertThrowsError(try lifecycle.transition(to: .completed))
    XCTAssertEqual(lifecycle.state, .pending)
  }
}
