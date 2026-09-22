public enum DependencyKind: String, Codable, Sendable {
  case after
  case afterAny = "afterany"
  case afterOK = "afterok"
  case afterNotOK = "afternotok"
  case singleton
}

public struct DependencyRequirement: Equatable, Codable, Sendable {
  public let kind: DependencyKind
  public let jobIDs: [JobID]

  public init(kind: DependencyKind, jobIDs: [JobID]) {
    self.kind = kind
    self.jobIDs = jobIDs
  }

  public static func parse(_ value: String) throws -> DependencyRequirement {
    let components = value.split(separator: ":", omittingEmptySubsequences: false)
    guard let kindValue = components.first,
      let kind = DependencyKind(rawValue: String(kindValue)),
      components.count > 1
    else {
      throw DependencyRequirementError.invalidValue(value)
    }
    let identifiers = try components.dropFirst().map { component in
      guard let identifier = Int64(component) else {
        throw DependencyRequirementError.invalidValue(value)
      }
      return JobID(identifier)
    }
    return DependencyRequirement(kind: kind, jobIDs: identifiers)
  }

  public func isSatisfied(by states: [JobID: JobState]) -> Bool {
    jobIDs.allSatisfy { identifier in
      guard let state = states[identifier] else { return false }
      return kind.isSatisfied(by: state)
    }
  }
}

public enum DependencyRequirementError: Error, Equatable {
  case invalidValue(String)
}

extension DependencyKind {
  fileprivate func isSatisfied(by state: JobState) -> Bool {
    switch self {
    case .after:
      ![.submitted, .validating, .pending].contains(state)
    case .afterAny:
      state.isTerminal
    case .afterOK:
      state == .completed
    case .afterNotOK:
      state.isTerminal && state != .completed
    case .singleton:
      false
    }
  }
}

extension JobState {
  fileprivate var isTerminal: Bool {
    [.completed, .failed, .cancelled, .timeout, .nodeFail].contains(self)
  }
}
