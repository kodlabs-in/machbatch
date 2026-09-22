import Foundation
import XCTest

final class CommandLineEndToEndTests: XCTestCase {
  func testSinfoWorksWithAutomaticFirstRunConfiguration() throws {
    let dataDirectory = FileManager.default.temporaryDirectory
      .appendingPathComponent("machbatch-e2e-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: dataDirectory) }

    let result = try runMachBatch(
      arguments: ["sinfo"],
      environment: ["MACHBATCH_DATA_DIR": dataDirectory.path]
    )

    XCTAssertEqual(result.status, 0, result.error)
    XCTAssertTrue(result.output.contains("PARTITION AVAIL"), result.output)
    XCTAssertTrue(result.output.contains("local*"), result.output)
  }

  func testDoctorChecksDatabaseAndHost() throws {
    let dataDirectory = FileManager.default.temporaryDirectory
      .appendingPathComponent("machbatch-doctor-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: dataDirectory) }

    let result = try runMachBatch(
      arguments: ["doctor"],
      environment: ["MACHBATCH_DATA_DIR": dataDirectory.path]
    )

    XCTAssertEqual(result.status, 0, result.error)
    XCTAssertTrue(result.output.contains("database: ok"), result.output)
    XCTAssertTrue(result.output.contains("architecture:"), result.output)
  }

  func testBatchSubmissionRunsThroughAccounting() throws {
    let dataDirectory = FileManager.default.temporaryDirectory
      .appendingPathComponent("machbatch-e2e-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: dataDirectory) }
    let environment = ["MACHBATCH_DATA_DIR": dataDirectory.path]

    let submission = try runExecutable(
      named: "machbatch",
      arguments: ["sbatch", "--wrap", "/usr/bin/true"],
      environment: environment
    )
    XCTAssertEqual(submission.status, 0, submission.error)
    XCTAssertEqual(submission.output, "Submitted batch job 1\n")

    let queued = try runMachBatch(arguments: ["squeue"], environment: environment)
    XCTAssertTrue(queued.output.contains(" 1 "), queued.output)
    XCTAssertTrue(queued.output.contains(" PD "), queued.output)

    let daemon = try runExecutable(
      named: "machbatchd",
      arguments: ["--once"],
      environment: environment
    )
    XCTAssertEqual(daemon.status, 0, daemon.error)

    let accounting = try runMachBatch(
      arguments: ["sacct", "--jobs", "1"],
      environment: environment
    )
    XCTAssertEqual(accounting.status, 0, accounting.error)
    XCTAssertTrue(accounting.output.contains("COMPLETED"), accounting.output)
  }

  func testUnsupportedOptionsFailInsteadOfBeingIgnored() throws {
    let result = try runMachBatch(
      arguments: ["sinfo", "--definitely-unsupported"],
      environment: [:]
    )

    XCTAssertNotEqual(result.status, 0)
    XCTAssertTrue(result.error.contains("--definitely-unsupported"), result.error)
  }

  func testScancelCancelsAPendingJob() throws {
    let dataDirectory = FileManager.default.temporaryDirectory
      .appendingPathComponent("machbatch-e2e-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: dataDirectory) }
    let environment = ["MACHBATCH_DATA_DIR": dataDirectory.path]
    _ = try runMachBatch(
      arguments: ["sbatch", "--wrap", "/usr/bin/true"],
      environment: environment
    )

    let cancellation = try runMachBatch(arguments: ["scancel", "1"], environment: environment)
    let accounting = try runMachBatch(
      arguments: ["sacct", "--jobs", "1"],
      environment: environment
    )

    XCTAssertEqual(cancellation.status, 0, cancellation.error)
    XCTAssertTrue(accounting.output.contains("CANCELLED"), accounting.output)
  }

  func testSubmittedScriptUsesImmutableSpoolCopy() throws {
    let dataDirectory = FileManager.default.temporaryDirectory
      .appendingPathComponent("machbatch-e2e-\(UUID().uuidString)")
    let scriptURL = FileManager.default.temporaryDirectory
      .appendingPathComponent("machbatch-script-\(UUID().uuidString).zsh")
    defer {
      try? FileManager.default.removeItem(at: dataDirectory)
      try? FileManager.default.removeItem(at: scriptURL)
    }
    try "#!/bin/zsh\n#SBATCH --job-name durable-script\nexit 0\n".write(
      to: scriptURL,
      atomically: true,
      encoding: .utf8
    )
    let environment = ["MACHBATCH_DATA_DIR": dataDirectory.path]

    let submission = try runMachBatch(
      arguments: ["sbatch", scriptURL.path], environment: environment)
    try "#!/bin/zsh\nexit 1\n".write(to: scriptURL, atomically: true, encoding: .utf8)
    let daemon = try runExecutable(
      named: "machbatchd",
      arguments: ["--once"],
      environment: environment
    )
    let accounting = try runMachBatch(
      arguments: ["sacct", "--jobs", "1"], environment: environment)

    XCTAssertEqual(submission.status, 0, submission.error)
    XCTAssertEqual(daemon.status, 0, daemon.error)
    XCTAssertTrue(accounting.output.contains("durable-script"), accounting.output)
    XCTAssertTrue(accounting.output.contains("COMPLETED"), accounting.output)
  }

  func testBatchExecutionUsesRequestedDirectoryOutputAndEnvironment() throws {
    let dataDirectory = FileManager.default.temporaryDirectory
      .appendingPathComponent("machbatch-e2e-\(UUID().uuidString)")
    let workingDirectory = dataDirectory.appendingPathComponent("work")
    defer { try? FileManager.default.removeItem(at: dataDirectory) }
    try FileManager.default.createDirectory(
      at: workingDirectory,
      withIntermediateDirectories: true
    )
    let environment = ["MACHBATCH_DATA_DIR": dataDirectory.path]

    let submission = try runMachBatch(
      arguments: [
        "sbatch", "--wrap", "printf \"$MODE:$PWD\"", "--chdir", workingDirectory.path,
        "--output", "result-%j.txt", "--export", "NONE,MODE=test",
      ],
      environment: environment
    )
    let daemon = try runExecutable(
      named: "machbatchd",
      arguments: ["--once"],
      environment: environment
    )
    let output = try String(
      contentsOf: workingDirectory.appendingPathComponent("result-1.txt"),
      encoding: .utf8
    )

    XCTAssertEqual(submission.status, 0, submission.error)
    XCTAssertEqual(daemon.status, 0, daemon.error)
    XCTAssertTrue(output.hasPrefix("test:"), output)
    let reportedDirectory = String(output.dropFirst("test:".count))
    let expectedIdentity = try fileIdentity(atPath: workingDirectory.path)
    let reportedIdentity = try fileIdentity(atPath: reportedDirectory)
    XCTAssertEqual(reportedIdentity, expectedIdentity)
  }

  private func runMachBatch(
    arguments: [String],
    environment: [String: String]
  ) throws -> CommandResult {
    try runExecutable(named: "machbatch", arguments: arguments, environment: environment)
  }

  private func fileIdentity(atPath path: String) throws -> [UInt64] {
    let attributes = try FileManager.default.attributesOfItem(atPath: path)
    return [.systemNumber, .systemFileNumber].map { key in
      (attributes[key] as? NSNumber)?.uint64Value ?? 0
    }
  }

  private func runExecutable(
    named executableName: String,
    arguments: [String],
    environment: [String: String]
  ) throws -> CommandResult {
    let process = Process()
    let productsDirectory = Bundle(for: Self.self).bundleURL.deletingLastPathComponent()
    process.executableURL = productsDirectory.appendingPathComponent(executableName)
    process.arguments = arguments
    process.environment = ProcessInfo.processInfo.environment.merging(environment) { _, new in new }
    if let dataDirectory = environment["MACHBATCH_DATA_DIR"] {
      try FileManager.default.createDirectory(
        atPath: dataDirectory,
        withIntermediateDirectories: true
      )
      process.currentDirectoryURL = URL(fileURLWithPath: dataDirectory)
    }

    let output = Pipe()
    let error = Pipe()
    process.standardOutput = output
    process.standardError = error
    try process.run()
    process.waitUntilExit()

    return CommandResult(
      status: process.terminationStatus,
      output: String(
        bytes: output.fileHandleForReading.readDataToEndOfFile(),
        encoding: .utf8
      ) ?? "",
      error: String(
        bytes: error.fileHandleForReading.readDataToEndOfFile(),
        encoding: .utf8
      ) ?? ""
    )
  }
}

private struct CommandResult {
  let status: Int32
  let output: String
  let error: String
}
