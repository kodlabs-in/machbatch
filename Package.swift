// swift-tools-version: 6.2

import PackageDescription

let package = Package(
  name: "machbatch",
  platforms: [.macOS(.v13)],
  products: [
    .executable(name: "machbatch", targets: ["CLI"]),
    .executable(name: "machbatchd", targets: ["ControllerDaemon"]),
    .library(name: "MachBatchCore", targets: ["ClusterCore"]),
  ],
  targets: [
    .target(name: "ClusterCore"),
    .target(name: "Config", dependencies: ["ClusterCore"]),
    .target(name: "Compatibility", dependencies: ["ClusterCore"]),
    .target(name: "ResourceProbe", dependencies: ["ClusterCore"]),
    .target(name: "PriorityEngine", dependencies: ["ClusterCore"]),
    .target(name: "Scheduler", dependencies: ["ClusterCore", "PriorityEngine"]),
    .systemLibrary(name: "CSQLite"),
    .target(
      name: "Persistence",
      dependencies: ["ClusterCore", "CSQLite"],
      linkerSettings: [.linkedLibrary("sqlite3")]
    ),
    .target(name: "Accounting", dependencies: ["ClusterCore", "Persistence"]),
    .target(name: "CProcessShim", publicHeadersPath: "include"),
    .target(name: "Executor", dependencies: ["ClusterCore", "CProcessShim"]),
    .target(
      name: "Controller",
      dependencies: ["ClusterCore", "Executor", "Persistence", "Scheduler"]
    ),
    .target(
      name: "RuntimeAdapters",
      dependencies: ["ClusterCore", "Compatibility", "Config"]
    ),
    .executableTarget(
      name: "CLI",
      dependencies: [
        "ClusterCore",
        "Compatibility",
        "Config",
        "Persistence",
        "ResourceProbe",
        "RuntimeAdapters",
      ]
    ),
    .executableTarget(
      name: "ControllerDaemon",
      dependencies: [
        "Accounting",
        "ClusterCore",
        "Config",
        "Controller",
        "Executor",
        "Persistence",
        "ResourceProbe",
        "Scheduler",
      ]
    ),
    .testTarget(
      name: "UnitTests",
      dependencies: [
        "Accounting",
        "ClusterCore",
        "Compatibility",
        "Config",
        "Executor",
        "Persistence",
        "PriorityEngine",
        "ResourceProbe",
        "RuntimeAdapters",
        "Scheduler",
      ],
      path: "Tests/Unit"
    ),
    .testTarget(
      name: "IntegrationTests",
      dependencies: ["ClusterCore", "Controller", "Executor", "Persistence", "Scheduler"],
      path: "Tests/Integration"
    ),
    .testTarget(
      name: "CompatibilityGoldenTests",
      dependencies: ["Compatibility"],
      path: "Tests/CompatibilityGolden"
    ),
    .testTarget(
      name: "CrashRecoveryTests",
      dependencies: ["ClusterCore", "Controller", "Executor", "Persistence", "Scheduler"],
      path: "Tests/CrashRecovery"
    ),
    .testTarget(
      name: "PackagingTests",
      dependencies: ["Compatibility"],
      path: "Tests/Packaging"
    ),
  ],
  swiftLanguageModes: [.v6]
)
