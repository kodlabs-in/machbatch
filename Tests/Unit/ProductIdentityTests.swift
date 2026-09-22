import Compatibility
import XCTest

final class ProductIdentityTests: XCTestCase {
  func testCurrentProfileIdentifiesMachBatchAndPinnedSlurmCompatibility() {
    let profile = CompatibilityProfile.current

    XCTAssertEqual(profile.name, "MachBatch")
    XCTAssertEqual(profile.releaseVersion, "0.1.1")
    XCTAssertEqual(profile.cliCompatibility, "Slurm 26.05.4 CLI-compatible")
  }
}
