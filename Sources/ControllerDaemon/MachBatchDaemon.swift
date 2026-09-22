import Config
import Controller
import Executor
import Foundation
import Persistence
import ResourceProbe

@main
enum MachBatchDaemon {
  static func main() {
    do {
      try run()
    } catch {
      FileHandle.standardError.write(Data("machbatchd: \(error)\n".utf8))
      Foundation.exit(EXIT_FAILURE)
    }
  }

  private static func run() throws {
    let paths = ApplicationPaths.resolve()
    try paths.prepare()
    let store = try SQLiteJobStore(path: paths.databaseURL.path)
    try store.migrate()
    let host = try SystemResourceProbe().probe()
    let configuration = try DefaultClusterConfigurationBuilder().build(for: host)
    let controller = ControllerService(
      store: store,
      capacity: configuration.allocatableResources,
      executor: ProcessJobExecutor()
    )
    try controller.scheduleOnce()
  }
}
