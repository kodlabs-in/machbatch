import ClusterCore
import XCTest

final class WallTimeParserTests: XCTestCase {
  func testParsesSlurmDayHourMinuteSecondDuration() throws {
    let wallTime = try WallTime.parse("2-03:04:05")

    XCTAssertEqual(wallTime.seconds, 183_845)
  }

  func testParsesSupportedSlurmDurationForms() throws {
    XCTAssertEqual(try WallTime.parse("30").seconds, 1_800)
    XCTAssertEqual(try WallTime.parse("03:04:05").seconds, 11_045)
    XCTAssertEqual(try WallTime.parse("2-03").seconds, 183_600)
    XCTAssertEqual(try WallTime.parse("2-03:04").seconds, 183_840)
  }
}
