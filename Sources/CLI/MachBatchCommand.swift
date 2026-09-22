import Foundation

@main
enum MachBatchCommand {
  static func main() {
    do {
      var arguments = Array(CommandLine.arguments.dropFirst())
      let invocation = URL(fileURLWithPath: CommandLine.arguments[0]).lastPathComponent
      let command = resolveCommand(invocation: invocation, arguments: &arguments)
      try CLIApplication().run(command: command, arguments: arguments)
    } catch {
      FileHandle.standardError.write(Data("machbatch: \(error)\n".utf8))
      Foundation.exit(EXIT_FAILURE)
    }
  }

  private static func resolveCommand(
    invocation: String,
    arguments: inout [String]
  ) -> String {
    guard invocation == "machbatch" else { return invocation }
    guard let command = arguments.first, !command.hasPrefix("-") else { return invocation }
    arguments.removeFirst()
    return command
  }
}
