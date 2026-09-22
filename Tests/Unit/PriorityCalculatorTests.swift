import PriorityEngine
import XCTest

final class PriorityCalculatorTests: XCTestCase {
  func testDisplayedTotalEqualsEverySchedulingFactor() {
    let factors = PriorityFactors(
      age: 100,
      association: 20,
      fairShare: 40,
      jobSize: 10,
      partition: 5,
      qos: 50,
      site: 2,
      nice: 7
    )

    XCTAssertEqual(PriorityCalculator().calculate(factors).total, 220)
  }
}
