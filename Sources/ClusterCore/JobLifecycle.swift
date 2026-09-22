public enum JobState: String, Codable, CaseIterable, Sendable {
  case submitted = "SUBMITTED"
  case validating = "VALIDATING"
  case pending = "PENDING"
  case allocated = "ALLOCATED"
  case starting = "STARTING"
  case running = "RUNNING"
  case suspended = "SUSPENDED"
  case completing = "COMPLETING"
  case completed = "COMPLETED"
  case failed = "FAILED"
  case cancelled = "CANCELLED"
  case timeout = "TIMEOUT"
  case nodeFail = "NODE_FAIL"
}

public struct JobLifecycle: Sendable {
  public private(set) var state: JobState

  public init(initialState: JobState) {
    state = initialState
  }

  public mutating func transition(to nextState: JobState) throws {
    guard Self.allowedTransitions[state, default: []].contains(nextState) else {
      throw JobLifecycleError.invalidTransition(from: state, newState: nextState)
    }
    state = nextState
  }

  private static let allowedTransitions: [JobState: Set<JobState>] = [
    .submitted: [.validating],
    .validating: [.pending, .failed],
    .pending: [.allocated, .cancelled],
    .allocated: [.starting, .pending, .cancelled, .failed],
    .starting: [.running, .failed, .cancelled],
    .running: [.suspended, .completing, .cancelled, .timeout, .nodeFail],
    .suspended: [.running, .cancelled, .timeout, .nodeFail],
    .completing: [.completed, .failed, .cancelled, .timeout, .nodeFail],
  ]
}

public enum JobLifecycleError: Error, Equatable {
  case invalidTransition(from: JobState, newState: JobState)
}
