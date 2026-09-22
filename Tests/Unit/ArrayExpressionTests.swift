import ClusterCore
import XCTest

final class ArrayExpressionTests: XCTestCase {
  func testExpandsSteppedRangeAndConcurrencyLimit() throws {
    let expression = try ArrayExpression.parse("1-7:2%2")

    XCTAssertEqual(expression.indices, [1, 3, 5, 7])
    XCTAssertEqual(expression.maximumConcurrentTasks, 2)
  }
}
