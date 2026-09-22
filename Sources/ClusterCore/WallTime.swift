public struct WallTime: Equatable, Codable, Sendable {
  public let seconds: Int

  public init(seconds: Int) {
    self.seconds = seconds
  }

  public static func parse(_ value: String) throws -> WallTime {
    let dayAndClock = value.split(separator: "-", omittingEmptySubsequences: false)
    guard (1...2).contains(dayAndClock.count) else {
      throw WallTimeParsingError.invalidValue(value)
    }

    let includesDays = dayAndClock.count == 2
    let days = try parseDays(dayAndClock, original: value)
    let clockValue = dayAndClock[includesDays ? 1 : 0]
    let clock = try parseClock(clockValue, includesDays: includesDays, original: value)

    return WallTime(seconds: days * 86_400 + clock)
  }

  private static func parseDays(
    _ parts: [Substring],
    original: String
  ) throws -> Int {
    guard parts.count == 2 else { return 0 }
    return try parseInteger(parts[0], original: original)
  }

  private static func parseClock(
    _ value: Substring,
    includesDays: Bool,
    original: String
  ) throws -> Int {
    let parts = try value.split(separator: ":", omittingEmptySubsequences: false)
      .map { try parseInteger($0, original: original) }

    return try clockSeconds(parts, includesDays: includesDays, original: original)
  }

  private static func clockSeconds(
    _ parts: [Int],
    includesDays: Bool,
    original: String
  ) throws -> Int {
    switch (includesDays, parts.count) {
    case (false, 1): return parts[0] * 60
    case (false, 2): return parts[0] * 60 + parts[1]
    case (false, 3): return parts[0] * 3_600 + parts[1] * 60 + parts[2]
    case (true, 1): return parts[0] * 3_600
    case (true, 2): return parts[0] * 3_600 + parts[1] * 60
    case (true, 3): return parts[0] * 3_600 + parts[1] * 60 + parts[2]
    default: throw WallTimeParsingError.invalidValue(original)
    }
  }

  private static func parseInteger(_ value: Substring, original: String) throws -> Int {
    guard let number = Int(value), number >= 0 else {
      throw WallTimeParsingError.invalidValue(original)
    }
    return number
  }
}

public enum WallTimeParsingError: Error, Equatable {
  case invalidValue(String)
}
