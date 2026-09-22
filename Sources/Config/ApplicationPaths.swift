import Foundation

public struct ApplicationPaths: Equatable, Sendable {
  public let root: URL

  public init(root: URL) {
    self.root = root
  }

  public var configurationDirectory: URL { root.appendingPathComponent("config") }
  public var databaseDirectory: URL { root.appendingPathComponent("database") }
  public var spoolDirectory: URL { root.appendingPathComponent("spool") }
  public var runDirectory: URL { root.appendingPathComponent("run") }
  public var backupDirectory: URL { root.appendingPathComponent("backups") }
  public var databaseURL: URL { databaseDirectory.appendingPathComponent("machbatch.sqlite") }

  public static func resolve(
    environment: [String: String] = ProcessInfo.processInfo.environment
  ) -> Self {
    if let override = environment["MACHBATCH_DATA_DIR"] {
      return ApplicationPaths(root: URL(fileURLWithPath: override, isDirectory: true))
    }
    let applicationSupport = FileManager.default.homeDirectoryForCurrentUser
      .appendingPathComponent("Library/Application Support", isDirectory: true)
    return ApplicationPaths(root: applicationSupport.appendingPathComponent("MachBatch"))
  }

  public func prepare() throws {
    for directory in directories {
      try FileManager.default.createDirectory(
        at: directory,
        withIntermediateDirectories: true,
        attributes: [.posixPermissions: 0o700]
      )
    }
  }

  private var directories: [URL] {
    [
      root,
      configurationDirectory,
      databaseDirectory,
      spoolDirectory,
      runDirectory,
      backupDirectory,
    ]
  }
}
