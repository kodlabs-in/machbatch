import ClusterCore
import XCTest

final class ResourceLedgerTests: XCTestCase {
  func testRejectsReservationThatWouldExceedPhysicalCapacity() throws {
    var ledger = ResourceLedger(capacity: Resources(cpuSlots: 4, memoryMiB: 8_192))
    try ledger.reserve(Resources(cpuSlots: 3, memoryMiB: 4_096), for: JobID(1))

    XCTAssertThrowsError(
      try ledger.reserve(Resources(cpuSlots: 2, memoryMiB: 1_024), for: JobID(2))
    )
    XCTAssertEqual(ledger.allocated, Resources(cpuSlots: 3, memoryMiB: 4_096))
  }

  func testReleasesAReservationExactlyOnce() throws {
    var ledger = ResourceLedger(capacity: Resources(cpuSlots: 4, memoryMiB: 8_192))
    try ledger.reserve(Resources(cpuSlots: 2, memoryMiB: 2_048), for: JobID(7))

    XCTAssertEqual(try ledger.release(for: JobID(7)), Resources(cpuSlots: 2, memoryMiB: 2_048))
    XCTAssertThrowsError(try ledger.release(for: JobID(7)))
    XCTAssertEqual(ledger.allocated, .zero)
  }
}
