import Foundation

public struct BatchDirectiveParser: Sendable {
  public init() {}

  public func parse(_ script: String) throws -> [String] {
    var arguments: [String] = []

    for line in script.split(separator: "\n", omittingEmptySubsequences: false) {
      let trimmed = line.trimmingCharacters(in: .whitespaces)
      if let directive = directiveBody(in: trimmed) {
        arguments.append(contentsOf: try ShellWordLexer().tokenize(directive))
        continue
      }
      if belongsToDirectiveRegion(trimmed) { continue }
      break
    }

    return arguments
  }

  private func directiveBody(in line: String) -> String? {
    let marker = "#SBATCH"
    guard line.hasPrefix(marker) else { return nil }
    return String(line.dropFirst(marker.count)).trimmingCharacters(in: .whitespaces)
  }

  private func belongsToDirectiveRegion(_ line: String) -> Bool {
    line.isEmpty || line.hasPrefix("#")
  }
}

private struct ShellWordLexer {
  private enum Quote {
    case single
    case double
  }

  func tokenize(_ value: String) throws -> [String] {
    var words: [String] = []
    var current = ""
    var quote: Quote?

    for character in value {
      switch (character, quote) {
      case ("'", nil): quote = .single
      case ("'", .single): quote = nil
      case ("\"", nil): quote = .double
      case ("\"", .double): quote = nil
      case (_, nil) where character.isWhitespace:
        append(&current, to: &words)
      default:
        current.append(character)
      }
    }

    guard quote == nil else {
      throw BatchDirectiveParsingError.unterminatedQuote
    }
    append(&current, to: &words)
    return words
  }

  private func append(_ current: inout String, to words: inout [String]) {
    guard !current.isEmpty else { return }
    words.append(current)
    current.removeAll(keepingCapacity: true)
  }
}

public enum BatchDirectiveParsingError: Error, Equatable {
  case unterminatedQuote
}
