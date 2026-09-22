import ClusterCore
import Scheduler
import XCTest

final class SchedulerEngineTests: XCTestCase {
  func testChoosesHighestPriorityThenOldestJobThatFits() {
    let jobs = [
      PendingJob(
        id: 3, resources: Resources(cpuSlots: 1, memoryMiB: 512), priority: 20, submissionOrder: 3),
      PendingJob(
        id: 1, resources: Resources(cpuSlots: 1, memoryMiB: 512), priority: 20, submissionOrder: 1),
      PendingJob(
        id: 2, resources: Resources(cpuSlots: 1, memoryMiB: 512), priority: 30, submissionOrder: 2),
    ]

    let selected = SchedulerEngine().select(
      from: jobs, available: Resources(cpuSlots: 2, memoryMiB: 1_024))

    XCTAssertEqual(selected.map(\.id), [JobID(2), JobID(1)])
  }
}
