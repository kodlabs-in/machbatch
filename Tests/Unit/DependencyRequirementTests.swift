import ClusterCore
import XCTest

final class DependencyRequirementTests: XCTestCase {
  func testAfterOKRequiresSuccessfulCompletion() throws {
    let requirement = try DependencyRequirement.parse("afterok:7")

    XCTAssertTrue(requirement.isSatisfied(by: [7: .completed]))
    XCTAssertFalse(requirement.isSatisfied(by: [7: .failed]))
  }
}
