import Compatibility
import XCTest

final class BatchDirectiveParserTests: XCTestCase {
  func testReadsDirectivesOnlyFromTheLeadingDirectiveRegion() throws {
    let script = """
      #!/bin/zsh
      #SBATCH --job-name="nightly build"
      #SBATCH --mem 2G

      echo hello
      #SBATCH --time=10
      """

    let arguments = try BatchDirectiveParser().parse(script)

    XCTAssertEqual(arguments, ["--job-name=nightly build", "--mem", "2G"])
  }
}
