import ClusterCore
import Executor
import Foundation
import XCTest

final class ProcessJobExecutorTests: XCTestCase {
  func testWritesExpandedDefaultOutputAndSlurmEnvironment() throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("machbatch-executor-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let submission = JobSubmission(
      name: "environment",
      user: "tester",
      partition: "local",
      command: ["/bin/zsh", "-c", "printf $SLURM_JOB_ID"],
      resources: Resources(cpuSlots: 1, memoryMiB: 128),
      wallTime: WallTime(seconds: 60),
      workingDirectory: directory.path,
      outputPath: "slurm-%j.out"
    )
    let job = JobRecord(
      id: 42,
      submission: submission,
      state: .running,
      submittedAt: Date()
    )

    let result = try ProcessJobExecutor().execute(job)
    let output = try String(
      contentsOf: directory.appendingPathComponent("slurm-42.out"),
      encoding: .utf8
    )

    XCTAssertTrue(result.succeeded)
    XCTAssertEqual(output, "42")
  }

  func testTerminatesAJobAfterItsWallTimeExpires() throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("machbatch-timeout-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let job = JobRecord(
      id: 43,
      submission: JobSubmission(
        name: "timeout",
        user: "tester",
        partition: "local",
        command: ["/bin/sleep", "5"],
        resources: Resources(cpuSlots: 1, memoryMiB: 128),
        wallTime: WallTime(seconds: 1),
        workingDirectory: directory.path
      ),
      state: .running,
      submittedAt: Date()
    )
    let startedAt = Date()

    let result = try ProcessJobExecutor().execute(job)

    XCTAssertTrue(result.timedOut)
    XCTAssertLessThan(Date().timeIntervalSince(startedAt), 4)
  }
}
