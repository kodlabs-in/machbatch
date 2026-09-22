import ClusterCore

public enum CompatibilityProfile {
  public static let current = ProductIdentity(
    name: "MachBatch",
    releaseVersion: "0.1.0",
    cliCompatibility: "Slurm 26.05.4 CLI-compatible"
  )
}
