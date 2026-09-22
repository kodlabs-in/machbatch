import CSQLite
import ClusterCore
import Foundation

public final class SQLiteJobStore {
  private var database: OpaquePointer?

  public init(path: String) throws {
    let flags = SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX
    guard sqlite3_open_v2(path, &database, flags, nil) == SQLITE_OK else {
      let message = databaseMessage
      sqlite3_close(database)
      database = nil
      throw SQLiteJobStoreError.database(message)
    }
    sqlite3_busy_timeout(database, 5_000)
    try execute("PRAGMA foreign_keys = ON")
    try execute("PRAGMA journal_mode = WAL")
  }

  deinit {
    sqlite3_close(database)
  }

  public func close() throws {
    guard let database else { return }
    guard sqlite3_close(database) == SQLITE_OK else {
      throw SQLiteJobStoreError.database(databaseMessage)
    }
    self.database = nil
  }

  public func migrate() throws {
    try transaction {
      try execute(Self.schema)
      try execute(
        "INSERT OR IGNORE INTO schema_migrations(version, applied_at) "
          + "VALUES (1, unixepoch())"
      )
    }
  }

  public func createJob(_ submission: JobSubmission) throws -> JobRecord {
    try transaction {
      let submittedAt = Date()
      let jobID = try insertJob(submission, submittedAt: submittedAt)
      try insertEvent(
        JobEvent(
          jobID: jobID,
          previousState: nil,
          newState: .submitted,
          actor: "system",
          reason: "submission received",
          timestamp: submittedAt
        ))
      try updateState(jobID: jobID, to: .validating)
      try insertEvent(
        JobEvent(
          jobID: jobID,
          previousState: .submitted,
          newState: .validating,
          actor: "system",
          reason: "validation started",
          timestamp: submittedAt
        ))
      try updateState(jobID: jobID, to: .pending)
      try insertEvent(
        JobEvent(
          jobID: jobID,
          previousState: .validating,
          newState: .pending,
          actor: "system",
          reason: "submission accepted",
          timestamp: submittedAt
        ))
      return JobRecord(
        id: jobID,
        submission: submission,
        state: .pending,
        submittedAt: submittedAt
      )
    }
  }

  public func job(id: JobID) throws -> JobRecord? {
    let sql = """
      SELECT name, user_name, partition_name, command_json, cpu_slots,
             memory_mib, wall_time_seconds, state, submitted_at
      FROM jobs WHERE id = ?
      """

    return try withStatement(sql) { statement in
      try bind(id.rawValue, at: 1, to: statement)
      let result = sqlite3_step(statement)
      guard result != SQLITE_DONE else { return nil }
      guard result == SQLITE_ROW else { throw databaseError() }
      return try decodeJob(id: id, from: statement)
    }
  }

  public func jobs(state: JobState) throws -> [JobRecord] {
    let sql = """
      SELECT id, name, user_name, partition_name, command_json, cpu_slots,
             memory_mib, wall_time_seconds, state, submitted_at
      FROM jobs WHERE state = ? ORDER BY id
      """

    return try withStatement(sql) { statement in
      try bind(state.rawValue, at: 1, to: statement)
      var records: [JobRecord] = []
      while sqlite3_step(statement) == SQLITE_ROW {
        let id = JobID(sqlite3_column_int64(statement, 0))
        records.append(try decodeJob(id: id, from: statement, columnOffset: 1))
      }
      return records
    }
  }

  public func jobs() throws -> [JobRecord] {
    let sql = """
      SELECT id, name, user_name, partition_name, command_json, cpu_slots,
             memory_mib, wall_time_seconds, state, submitted_at
      FROM jobs ORDER BY id
      """

    return try withStatement(sql) { statement in
      var records: [JobRecord] = []
      while sqlite3_step(statement) == SQLITE_ROW {
        let id = JobID(sqlite3_column_int64(statement, 0))
        records.append(try decodeJob(id: id, from: statement, columnOffset: 1))
      }
      return records
    }
  }

  public func transition(
    jobID: JobID,
    to newState: JobState,
    actor: String = "system",
    reason: String
  ) throws {
    try transaction {
      guard let record = try job(id: jobID) else {
        throw SQLiteJobStoreError.jobNotFound(jobID)
      }
      var lifecycle = JobLifecycle(initialState: record.state)
      try lifecycle.transition(to: newState)
      try updateState(jobID: jobID, to: newState)
      try insertEvent(
        JobEvent(
          jobID: jobID,
          previousState: record.state,
          newState: newState,
          actor: actor,
          reason: reason,
          timestamp: Date()
        ))
    }
  }

  private func insertJob(_ submission: JobSubmission, submittedAt: Date) throws -> JobID {
    let sql = """
      INSERT INTO jobs(
          name, user_name, partition_name, command_json, cpu_slots,
          memory_mib, wall_time_seconds, state, submitted_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
      """

    return try withStatement(sql) { statement in
      let commandJSON = try encode(StoredExecution(submission: submission))
      try bind(submission.name, at: 1, to: statement)
      try bind(submission.user, at: 2, to: statement)
      try bind(submission.partition, at: 3, to: statement)
      try bind(commandJSON, at: 4, to: statement)
      try bind(Int64(submission.resources.cpuSlots), at: 5, to: statement)
      try bind(submission.resources.memoryMiB, at: 6, to: statement)
      try bind(Int64(submission.wallTime.seconds), at: 7, to: statement)
      try bind(JobState.submitted.rawValue, at: 8, to: statement)
      try bind(submittedAt.timeIntervalSince1970, at: 9, to: statement)
      try expectDone(statement)
      return JobID(sqlite3_last_insert_rowid(database))
    }
  }

  private func updateState(jobID: JobID, to state: JobState) throws {
    try withStatement("UPDATE jobs SET state = ? WHERE id = ?") { statement in
      try bind(state.rawValue, at: 1, to: statement)
      try bind(jobID.rawValue, at: 2, to: statement)
      try expectDone(statement)
    }
  }

  private func insertEvent(_ event: JobEvent) throws {
    let sql = """
      INSERT INTO job_events(job_id, previous_state, new_state, actor, reason, created_at)
      VALUES (?, ?, ?, ?, ?, ?)
      """

    try withStatement(sql) { statement in
      try bind(event.jobID.rawValue, at: 1, to: statement)
      try bind(event.previousState?.rawValue, at: 2, to: statement)
      try bind(event.newState.rawValue, at: 3, to: statement)
      try bind(event.actor, at: 4, to: statement)
      try bind(event.reason, at: 5, to: statement)
      try bind(event.timestamp.timeIntervalSince1970, at: 6, to: statement)
      try expectDone(statement)
    }
  }

  private func decodeJob(
    id: JobID,
    from statement: OpaquePointer,
    columnOffset: Int32 = 0
  ) throws -> JobRecord {
    let execution = try decodeExecution(text(at: columnOffset + 3, from: statement))
    guard let state = JobState(rawValue: text(at: columnOffset + 7, from: statement)) else {
      throw SQLiteJobStoreError.invalidStoredState
    }
    let submission = JobSubmission(
      name: text(at: columnOffset, from: statement),
      user: text(at: columnOffset + 1, from: statement),
      partition: text(at: columnOffset + 2, from: statement),
      command: execution.command,
      resources: Resources(
        cpuSlots: Int(sqlite3_column_int64(statement, columnOffset + 4)),
        memoryMiB: sqlite3_column_int64(statement, columnOffset + 5)
      ),
      wallTime: WallTime(seconds: Int(sqlite3_column_int64(statement, columnOffset + 6))),
      workingDirectory: execution.workingDirectory,
      outputPath: execution.outputPath,
      errorPath: execution.errorPath,
      environment: execution.environment
    )
    let submittedAt = Date(
      timeIntervalSince1970: sqlite3_column_double(statement, columnOffset + 8)
    )
    return JobRecord(id: id, submission: submission, state: state, submittedAt: submittedAt)
  }
}

extension SQLiteJobStore {
  private func transaction<T>(_ work: () throws -> T) throws -> T {
    try execute("BEGIN IMMEDIATE")
    do {
      let result = try work()
      try execute("COMMIT")
      return result
    } catch {
      try? execute("ROLLBACK")
      throw error
    }
  }

  private func execute(_ sql: String) throws {
    guard let database else { throw SQLiteJobStoreError.closed }
    var errorMessage: UnsafeMutablePointer<CChar>?
    guard sqlite3_exec(database, sql, nil, nil, &errorMessage) == SQLITE_OK else {
      let message = errorMessage.map { String(cString: $0) } ?? databaseMessage
      sqlite3_free(errorMessage)
      throw SQLiteJobStoreError.database(message)
    }
  }

  private func withStatement<T>(
    _ sql: String,
    body: (OpaquePointer) throws -> T
  ) throws -> T {
    guard let database else { throw SQLiteJobStoreError.closed }
    var statement: OpaquePointer?
    guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK,
      let statement
    else {
      throw databaseError()
    }
    defer { sqlite3_finalize(statement) }
    return try body(statement)
  }

  private func expectDone(_ statement: OpaquePointer) throws {
    guard sqlite3_step(statement) == SQLITE_DONE else { throw databaseError() }
  }

  private func bind(_ value: String, at index: Int32, to statement: OpaquePointer) throws {
    let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
    guard sqlite3_bind_text(statement, index, value, -1, transient) == SQLITE_OK else {
      throw databaseError()
    }
  }

  private func bind(_ value: String?, at index: Int32, to statement: OpaquePointer) throws {
    guard let value else {
      guard sqlite3_bind_null(statement, index) == SQLITE_OK else { throw databaseError() }
      return
    }
    try bind(value, at: index, to: statement)
  }

  private func bind(_ value: Int64, at index: Int32, to statement: OpaquePointer) throws {
    guard sqlite3_bind_int64(statement, index, value) == SQLITE_OK else {
      throw databaseError()
    }
  }

  private func bind(_ value: Double, at index: Int32, to statement: OpaquePointer) throws {
    guard sqlite3_bind_double(statement, index, value) == SQLITE_OK else {
      throw databaseError()
    }
  }

  private func text(at index: Int32, from statement: OpaquePointer) -> String {
    guard let value = sqlite3_column_text(statement, index) else { return "" }
    return String(cString: value)
  }

  private func encode<T: Encodable>(_ value: T) throws -> String {
    let data = try JSONEncoder().encode(value)
    guard let string = String(data: data, encoding: .utf8) else {
      throw SQLiteJobStoreError.invalidJSON
    }
    return string
  }

  private func decode<T: Decodable>(_ value: String) throws -> T {
    guard let data = value.data(using: .utf8) else {
      throw SQLiteJobStoreError.invalidJSON
    }
    return try JSONDecoder().decode(T.self, from: data)
  }

  private func decodeExecution(_ value: String) throws -> StoredExecution {
    do {
      return try decode(value)
    } catch {
      let legacyCommand: [String] = try decode(value)
      return StoredExecution(command: legacyCommand)
    }
  }

  private func databaseError() -> SQLiteJobStoreError {
    .database(databaseMessage)
  }

  private var databaseMessage: String {
    guard let database, let message = sqlite3_errmsg(database) else {
      return "SQLite operation failed"
    }
    return String(cString: message)
  }
}

public enum SQLiteJobStoreError: Error, Equatable {
  case closed
  case database(String)
  case invalidJSON
  case invalidStoredState
  case jobNotFound(JobID)
}

private struct JobEvent {
  let jobID: JobID
  let previousState: JobState?
  let newState: JobState
  let actor: String
  let reason: String
  let timestamp: Date
}

private struct StoredExecution: Codable {
  let command: [String]
  let workingDirectory: String
  let outputPath: String
  let errorPath: String?
  let environment: [String: String]

  init(submission: JobSubmission) {
    command = submission.command
    workingDirectory = submission.workingDirectory
    outputPath = submission.outputPath
    errorPath = submission.errorPath
    environment = submission.environment
  }

  init(command: [String]) {
    self.command = command
    workingDirectory = FileManager.default.currentDirectoryPath
    outputPath = "slurm-%j.out"
    errorPath = nil
    environment = [:]
  }
}

extension SQLiteJobStore {
  fileprivate static let schema = """
    CREATE TABLE IF NOT EXISTS schema_migrations(
        version INTEGER PRIMARY KEY,
        applied_at REAL NOT NULL
    );
    CREATE TABLE IF NOT EXISTS physical_hosts(
        id INTEGER PRIMARY KEY,
        hostname TEXT NOT NULL,
        architecture TEXT NOT NULL,
        cpu_slots INTEGER NOT NULL,
        memory_mib INTEGER NOT NULL
    );
    CREATE TABLE IF NOT EXISTS logical_nodes(
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL UNIQUE,
        cpu_slots INTEGER NOT NULL,
        memory_mib INTEGER NOT NULL,
        state TEXT NOT NULL,
        reason TEXT
    );
    CREATE TABLE IF NOT EXISTS partitions(
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL UNIQUE,
        is_default INTEGER NOT NULL DEFAULT 0
    );
    CREATE TABLE IF NOT EXISTS jobs(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        user_name TEXT NOT NULL,
        partition_name TEXT NOT NULL,
        command_json TEXT NOT NULL,
        cpu_slots INTEGER NOT NULL CHECK(cpu_slots > 0),
        memory_mib INTEGER NOT NULL CHECK(memory_mib > 0),
        wall_time_seconds INTEGER NOT NULL CHECK(wall_time_seconds > 0),
        state TEXT NOT NULL,
        submitted_at REAL NOT NULL
    );
    CREATE TABLE IF NOT EXISTS job_steps(
        id INTEGER PRIMARY KEY,
        job_id INTEGER NOT NULL REFERENCES jobs(id),
        state TEXT NOT NULL
    );
    CREATE TABLE IF NOT EXISTS job_tasks(
        id INTEGER PRIMARY KEY,
        step_id INTEGER NOT NULL REFERENCES job_steps(id),
        rank INTEGER NOT NULL
    );
    CREATE TABLE IF NOT EXISTS allocations(
        id INTEGER PRIMARY KEY,
        job_id INTEGER NOT NULL REFERENCES jobs(id),
        created_at REAL NOT NULL
    );
    CREATE TABLE IF NOT EXISTS resource_ledger(
        job_id INTEGER PRIMARY KEY REFERENCES jobs(id),
        cpu_slots INTEGER NOT NULL,
        memory_mib INTEGER NOT NULL
    );
    CREATE TABLE IF NOT EXISTS job_events(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        job_id INTEGER NOT NULL REFERENCES jobs(id),
        previous_state TEXT,
        new_state TEXT NOT NULL,
        actor TEXT NOT NULL,
        reason TEXT NOT NULL,
        created_at REAL NOT NULL
    );
    CREATE TABLE IF NOT EXISTS accounts(id INTEGER PRIMARY KEY, name TEXT NOT NULL UNIQUE);
    CREATE TABLE IF NOT EXISTS users(id INTEGER PRIMARY KEY, name TEXT NOT NULL UNIQUE);
    CREATE TABLE IF NOT EXISTS associations(
        id INTEGER PRIMARY KEY,
        account_id INTEGER NOT NULL REFERENCES accounts(id),
        user_id INTEGER NOT NULL REFERENCES users(id)
    );
    CREATE TABLE IF NOT EXISTS qos(id INTEGER PRIMARY KEY, name TEXT NOT NULL UNIQUE, limits_json TEXT NOT NULL);
    CREATE TABLE IF NOT EXISTS usage_samples(
        id INTEGER PRIMARY KEY,
        job_id INTEGER NOT NULL REFERENCES jobs(id),
        sampled_at REAL NOT NULL,
        resident_memory_bytes INTEGER,
        cpu_seconds REAL
    );
    CREATE TABLE IF NOT EXISTS usage_rollups(
        id INTEGER PRIMARY KEY,
        job_id INTEGER NOT NULL REFERENCES jobs(id),
        values_json TEXT NOT NULL
    );
    CREATE TABLE IF NOT EXISTS dependencies(
        job_id INTEGER NOT NULL REFERENCES jobs(id),
        dependency_job_id INTEGER NOT NULL REFERENCES jobs(id),
        kind TEXT NOT NULL,
        PRIMARY KEY(job_id, dependency_job_id, kind)
    );
    CREATE TABLE IF NOT EXISTS array_elements(
        job_id INTEGER NOT NULL REFERENCES jobs(id),
        task_index INTEGER NOT NULL,
        state TEXT NOT NULL,
        PRIMARY KEY(job_id, task_index)
    );
    CREATE TABLE IF NOT EXISTS generic_resources(
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        total INTEGER NOT NULL,
        allocated INTEGER NOT NULL,
        properties_json TEXT NOT NULL
    );
    """
}
