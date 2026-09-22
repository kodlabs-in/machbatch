import ClusterCore

public enum CompatibilityProfile {
    public static let current = ProductIdentity(
        name: "MachBatch",
        cliCompatibility: "Slurm 26.05.4 CLI-compatible"
    )
}

