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

  func testBackfillsSmallerJobWhenPriorityHeadCannotFit() {
    let jobs = [
      PendingJob(
        id: 1,
        resources: Resources(cpuSlots: 4, memoryMiB: 4_096),
        priority: 100,
        submissionOrder: 1
      ),
      PendingJob(
        id: 2,
        resources: Resources(cpuSlots: 1, memoryMiB: 512),
        priority: 10,
        submissionOrder: 2
      ),
    ]

    let selected = SchedulerEngine().select(
      from: jobs,
      available: Resources(cpuSlots: 2, memoryMiB: 2_048)
    )

    XCTAssertEqual(selected.map(\.id), [JobID(2)])
  }
}
