import Compatibility
import XCTest

final class CompatibilityManifestTests: XCTestCase {
  func testManifestAdvertisesExactlyTheElevenV1Commands() {
    let names = Set(CompatibilityManifest.current.commands.map(\.command.rawValue))

    XCTAssertEqual(
      names,
      Set([
        "sinfo", "squeue", "sbatch", "srun", "salloc", "scancel", "sacct", "sstat",
        "sprio", "scontrol", "sacctmgr",
      ])
    )
  }

  func testUnsupportedOptionIsRejectedInsteadOfIgnored() {
    XCTAssertThrowsError(
      try CompatibilityManifest.current.validate(
        command: .sinfo,
        arguments: ["--definitely-unsupported"]
      )
    )
  }
}
