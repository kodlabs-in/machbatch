import ClusterCore
import Foundation
import Persistence
import XCTest

final class SQLiteJobStoreTests: XCTestCase {
  func testJobsSurviveReopenAndIDsRemainMonotonic() throws {
    let databaseURL = temporaryDatabaseURL()
    defer { try? FileManager.default.removeItem(at: databaseURL) }

    let firstStore = try SQLiteJobStore(path: databaseURL.path)
    try firstStore.migrate()
    let firstJob = try firstStore.createJob(sampleSubmission(name: "first"))
    try firstStore.close()

    let reopenedStore = try SQLiteJobStore(path: databaseURL.path)
    try reopenedStore.migrate()
    let secondJob = try reopenedStore.createJob(sampleSubmission(name: "second"))

    XCTAssertEqual(firstJob.id, JobID(1))
    XCTAssertEqual(secondJob.id, JobID(2))
    XCTAssertEqual(try reopenedStore.job(id: firstJob.id)?.state, .pending)
  }

  func testExecutionContextSurvivesReopen() throws {
    let databaseURL = temporaryDatabaseURL()
    defer { try? FileManager.default.removeItem(at: databaseURL) }
    let submission = JobSubmission(
      name: "context",
      user: "tester",
      partition: "local",
      command: ["/usr/bin/printenv", "MODE"],
      resources: Resources(cpuSlots: 1, memoryMiB: 128),
      wallTime: WallTime(seconds: 60),
      workingDirectory: "/private/tmp",
      outputPath: "custom-%j.out",
      errorPath: "custom-%j.err",
      environment: ["MODE": "test"]
    )
    let store = try SQLiteJobStore(path: databaseURL.path)
    try store.migrate()
    let created = try store.createJob(submission)
    try store.close()

    let reopened = try SQLiteJobStore(path: databaseURL.path)
    try reopened.migrate()

    XCTAssertEqual(try reopened.job(id: created.id)?.submission, submission)
  }

  func testIntegrityCheckReportsHealthyDatabase() throws {
    let databaseURL = temporaryDatabaseURL()
    defer { try? FileManager.default.removeItem(at: databaseURL) }
    let store = try SQLiteJobStore(path: databaseURL.path)
    try store.migrate()

    XCTAssertTrue(try store.integrityCheck())
  }

  private func sampleSubmission(name: String) -> JobSubmission {
    JobSubmission(
      name: name,
      user: "tester",
      partition: "local",
      command: ["/usr/bin/true"],
      resources: Resources(cpuSlots: 1, memoryMiB: 128),
      wallTime: WallTime(seconds: 60)
    )
  }

  private func temporaryDatabaseURL() -> URL {
    FileManager.default.temporaryDirectory
      .appendingPathComponent("machbatch-\(UUID().uuidString).sqlite")
  }
}
