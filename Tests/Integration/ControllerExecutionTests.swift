import ClusterCore
import Controller
import Darwin
import Executor
import Foundation
import Persistence
import XCTest

final class ControllerExecutionTests: XCTestCase {
  func testSubmissionRunsToCompletionAndReleasesResources() throws {
    let workingDirectory = FileManager.default.temporaryDirectory
      .appendingPathComponent("machbatch-controller-\(UUID().uuidString)")
    try FileManager.default.createDirectory(
      at: workingDirectory,
      withIntermediateDirectories: true
    )
    defer { try? FileManager.default.removeItem(at: workingDirectory) }
    let databaseURL = workingDirectory.appendingPathComponent("jobs.sqlite")
    let store = try SQLiteJobStore(path: databaseURL.path)
    try store.migrate()
    let controller = ControllerService(
      store: store,
      capacity: Resources(cpuSlots: 2, memoryMiB: 2_048),
      executor: ProcessJobExecutor()
    )
    let submission = JobSubmission(
      name: "successful-job",
      user: "tester",
      partition: "local",
      command: ["/usr/bin/true"],
      resources: Resources(cpuSlots: 1, memoryMiB: 128),
      wallTime: WallTime(seconds: 60),
      workingDirectory: workingDirectory.path
    )

    let submitted = try controller.submit(submission)
    try controller.scheduleOnce()

    XCTAssertEqual(try store.job(id: submitted.id)?.state, .completed)
    XCTAssertEqual(controller.allocatedResources, .zero)
  }

  func testTimedOutExecutionIsRecordedAsTimeout() throws {
    let databaseURL = FileManager.default.temporaryDirectory
      .appendingPathComponent("machbatch-timeout-\(UUID().uuidString).sqlite")
    defer { try? FileManager.default.removeItem(at: databaseURL) }
    let store = try SQLiteJobStore(path: databaseURL.path)
    try store.migrate()
    let controller = ControllerService(
      store: store,
      capacity: Resources(cpuSlots: 1, memoryMiB: 128),
      executor: TimedOutExecutor()
    )
    let submitted = try controller.submit(
      JobSubmission(
        name: "timeout",
        user: "tester",
        partition: "local",
        command: ["/bin/sleep", "5"],
        resources: Resources(cpuSlots: 1, memoryMiB: 128),
        wallTime: WallTime(seconds: 1)
      ))

    try controller.scheduleOnce()

    XCTAssertEqual(try store.job(id: submitted.id)?.state, .timeout)
    XCTAssertEqual(controller.allocatedResources, .zero)
  }
}

private struct TimedOutExecutor: JobExecuting {
  func execute(_: JobRecord) throws -> ExecutionResult {
    ExecutionResult(exitStatus: SIGTERM, terminatingSignal: SIGTERM, timedOut: true)
  }
}
