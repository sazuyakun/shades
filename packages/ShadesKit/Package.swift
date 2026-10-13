// swift-tools-version: 6.2
import PackageDescription

let package = Package(
  name: "ShadesKit",
  platforms: [.macOS(.v15)],
  products: [
    .library(
      name: "ShadesKit",
      targets: [
        "ShadesCore",
        "ShadesCommands",
        "ShadesMedia",
        "ShadesEngine",
        "ShadesMCP",
        "ShadesUI",
      ],
    )
  ],
  dependencies: [
    .package(url: "https://github.com/modelcontextprotocol/swift-sdk.git", from: "0.12.1")
  ],
  targets: [
    .target(name: "ShadesCore"),
    .target(name: "ShadesCommands", dependencies: ["ShadesCore"]),
    .target(name: "ShadesMedia", dependencies: ["ShadesCore"]),
    .target(
      name: "ShadesEngine",
      dependencies: ["ShadesCore"],
      resources: [.copy("Shaders")],
    ),
    .target(
      name: "ShadesMCP",
      dependencies: [
        "ShadesCommands",
        "ShadesEngine",
        "ShadesMedia",
        .product(name: "MCP", package: "swift-sdk"),
      ],
    ),
    // ShadesUI runs on the main actor by default; every other module is nonisolated.
    .target(
      name: "ShadesUI",
      dependencies: ["ShadesCommands", "ShadesEngine", "ShadesMedia"],
      swiftSettings: [.defaultIsolation(MainActor.self)],
    ),
    .target(name: "ShadesTestSupport", path: "Tests/ShadesTestSupport"),
    .testTarget(name: "ShadesCoreTests", dependencies: ["ShadesCore"]),
    .testTarget(name: "ShadesCommandsTests", dependencies: ["ShadesCommands"]),
    .testTarget(name: "ShadesMediaTests", dependencies: ["ShadesMedia", "ShadesTestSupport"]),
    .testTarget(name: "ShadesEngineTests", dependencies: ["ShadesEngine", "ShadesTestSupport"]),
    .testTarget(name: "ShadesMCPTests", dependencies: ["ShadesMCP", "ShadesTestSupport"]),
  ],
)

// Swift 6.2 "approachable concurrency" everywhere: async functions run on their caller's actor
// unless marked `@concurrent`.
for target in package.targets {
  target.swiftSettings = (target.swiftSettings ?? []) + [
    .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
    .enableUpcomingFeature("InferIsolatedConformances"),
  ]
}
