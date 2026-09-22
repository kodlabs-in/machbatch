public struct MemorySize: Equatable, Codable, Sendable {
  public let mebibytes: Int64

  public init(mebibytes: Int64) {
    self.mebibytes = mebibytes
  }

  public static func parse(_ value: String) throws -> MemorySize {
    let normalized = value.uppercased()
    let suffix = normalized.last.map(String.init) ?? ""
    let hasUnit = multipliers[suffix] != nil
    let digits = hasUnit ? String(normalized.dropLast()) : normalized
    let multiplier = multipliers[suffix] ?? 1

    guard let amount = Int64(digits), amount > 0 else {
      throw MemorySizeParsingError.invalidValue(value)
    }

    let (mebibytes, overflow) = amount.multipliedReportingOverflow(by: multiplier)
    guard !overflow else {
      throw MemorySizeParsingError.invalidValue(value)
    }
    return MemorySize(mebibytes: mebibytes)
  }

  private static let multipliers: [String: Int64] = [
    "M": 1,
    "G": 1_024,
    "T": 1_048_576,
  ]
}

public enum MemorySizeParsingError: Error, Equatable {
  case invalidValue(String)
}
