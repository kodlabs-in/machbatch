public struct ArrayExpression: Equatable, Sendable {
  public let indices: [Int]
  public let maximumConcurrentTasks: Int?

  public init(indices: [Int], maximumConcurrentTasks: Int?) {
    self.indices = indices
    self.maximumConcurrentTasks = maximumConcurrentTasks
  }

  public static func parse(_ value: String) throws -> ArrayExpression {
    let concurrencyParts = value.split(separator: "%", omittingEmptySubsequences: false)
    guard (1...2).contains(concurrencyParts.count) else {
      throw ArrayExpressionError.invalidValue(value)
    }

    let limit = try parseLimit(concurrencyParts, original: value)
    let indices = try parseRange(concurrencyParts[0], original: value)
    return ArrayExpression(indices: indices, maximumConcurrentTasks: limit)
  }

  private static func parseLimit(
    _ parts: [Substring],
    original: String
  ) throws -> Int? {
    guard parts.count == 2 else { return nil }
    guard let limit = Int(parts[1]), limit > 0 else {
      throw ArrayExpressionError.invalidValue(original)
    }
    return limit
  }

  private static func parseRange(_ value: Substring, original: String) throws -> [Int] {
    let rangeAndStep = value.split(separator: ":", omittingEmptySubsequences: false)
    let endpoints = rangeAndStep[0].split(separator: "-", omittingEmptySubsequences: false)

    guard (1...2).contains(rangeAndStep.count),
      endpoints.count == 2,
      let lowerBound = Int(endpoints[0]),
      let upperBound = Int(endpoints[1]),
      lowerBound <= upperBound
    else {
      throw ArrayExpressionError.invalidValue(original)
    }

    let step = try parseStep(rangeAndStep, original: original)
    return Array(stride(from: lowerBound, through: upperBound, by: step))
  }

  private static func parseStep(_ parts: [Substring], original: String) throws -> Int {
    guard parts.count == 2 else { return 1 }
    guard let step = Int(parts[1]), step > 0 else {
      throw ArrayExpressionError.invalidValue(original)
    }
    return step
  }
}

public enum ArrayExpressionError: Error, Equatable {
  case invalidValue(String)
}
