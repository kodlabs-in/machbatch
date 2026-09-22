import Compatibility
import XCTest

final class BatchOptionResolverTests: XCTestCase {
  func testCommandLineOptionsOverrideScriptDirectives() throws {
    let script = """
      #!/bin/zsh
      #SBATCH --job-name script-name
      #SBATCH --mem=1G
      """

    let options = try BatchOptionResolver().resolve(
      script: script,
      commandLine: ["--job-name", "cli-name", "--mem", "2G", "-c", "2", "--time", "00:30:00"]
    )

    XCTAssertEqual(options.jobName, "cli-name")
    XCTAssertEqual(options.memoryMiB, 2_048)
    XCTAssertEqual(options.cpuSlots, 2)
    XCTAssertEqual(options.wallTime.seconds, 1_800)
  }

  func testResolvesExecutionContextAndEnvironmentExport() throws {
    let script = """
      #!/bin/zsh
      #SBATCH --output=script.out
      #SBATCH --chdir=/script
      """

    let options = try BatchOptionResolver().resolve(
      script: script,
      commandLine: [
        "--output", "logs/%j.out", "--error=logs/%j.err", "-D", "/work",
        "--export", "NONE,MODE=test",
      ]
    )

    XCTAssertEqual(options.outputPath, "logs/%j.out")
    XCTAssertEqual(options.errorPath, "logs/%j.err")
    XCTAssertEqual(options.workingDirectory, "/work")
    XCTAssertFalse(options.environmentExport.inheritsSubmissionEnvironment)
    XCTAssertEqual(options.environmentExport.assignments, ["MODE": "test"])
  }
}
