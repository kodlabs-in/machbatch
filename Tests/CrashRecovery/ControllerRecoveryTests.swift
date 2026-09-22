import ClusterCore
import Controller
import Executor
import Foundation
import Persistence
import XCTest

final class ControllerRecoveryTests: XCTestCase {
  func testMarksUnsupervisedRunningJobAsNodeFailureAfterRestart() throws {
    let databaseURL = temporaryDatabaseURL()
    defer { try? FileManager.default.removeItem(at: databaseURL) }
    let store = try SQLiteJobStore(path: databaseURL.path)
    try store.migrate()
    let job = try store.createJob(sampleSubmission())
    try store.transition(jobID: job.id, to: .allocated, reason: "test")
    try store.transition(jobID: job.id, to: .starting, reason: "test")
    try store.transition(jobID: job.id, to: .running, reason: "test")
    let restartedController = ControllerService(
      store: store,
      capacity: Resources(cpuSlots: 2, memoryMiB: 2_048),
      executor: NeverExecutor()
    )

    try restartedController.recoverInterruptedJobs(liveJobIDs: [])

    XCTAssertEqual(try store.job(id: job.id)?.state, .nodeFail)
  }

  private func sampleSubmission() -> JobSubmission {
    JobSubmission(
      name: "interrupted",
      user: "tester",
      partition: "local",
      command: ["/usr/bin/true"],
      resources: Resources(cpuSlots: 1, memoryMiB: 128),
      wallTime: WallTime(seconds: 60)
    )
  }

  private func temporaryDatabaseURL() -> URL {
    FileManager.default.temporaryDirectory
      .appendingPathComponent("machbatch-recovery-\(UUID().uuidString).sqlite")
  }
}

private struct NeverExecutor: JobExecuting {
  func execute(_: JobRecord) throws -> ExecutionResult {
    XCTFail("Recovery must not execute interrupted jobs")
    return ExecutionResult(exitStatus: 1, terminatingSignal: nil)
  }
}
