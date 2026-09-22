import Compatibility

@main
enum MachBatchCommand {
  static func main() {
    let profile = CompatibilityProfile.current
    print("\(profile.name) — \(profile.cliCompatibility)")
  }
}
