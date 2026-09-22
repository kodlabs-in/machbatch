import ClusterCore
import XCTest

final class MemoryParserTests: XCTestCase {
  func testParsesSupportedSlurmMemoryUnitsIntoMiB() throws {
    XCTAssertEqual(try MemorySize.parse("1024").mebibytes, 1_024)
    XCTAssertEqual(try MemorySize.parse("2G").mebibytes, 2_048)
    XCTAssertEqual(try MemorySize.parse("1T").mebibytes, 1_048_576)
    XCTAssertEqual(try MemorySize.parse("512M").mebibytes, 512)
  }
}
