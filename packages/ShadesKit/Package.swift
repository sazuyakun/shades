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
        "ShadesCaptions",
        "ShadesCommands",
        "ShadesDocument",
        "ShadesMedia",
        "ShadesEngine",
        "ShadesMCP",
        "ShadesPlugins",
        "ShadesUI",
      ],
    )
  ],
  dependencies: [
    .package(url: "https://github.com/argmaxinc/WhisperKit.git", exact: "1.1.0")
  ],
  targets: [
    .target(name: "ShadesCore"),
    .target(name: "ShadesCommands", dependencies: ["ShadesCore"]),
    .target(name: "ShadesDocument", dependencies: ["ShadesCore"]),
    .target(
      name: "ShadesCaptions",
      dependencies: ["ShadesCore", .product(name: "WhisperKit", package: "WhisperKit")],
    ),
    .target(name: "ShadesMedia", dependencies: ["ShadesCore"]),
    .target(name: "ShadesPlugins"),
    .target(
      name: "ShadesEngine",
      dependencies: ["ShadesCore"],
      resources: [.copy("Shaders")],
    ),
    .target(
      name: "ShadesMCP",
      dependencies: [
        "ShadesCommands",
        "ShadesDocument",
        "ShadesEngine",
        "ShadesMedia",
      ],
    ),
    // ShadesUI sits above ShadesMCP (to show Claude's status) and runs on the main actor by
    // default; every other module is nonisolated.
    .target(
      name: "ShadesUI",
      dependencies: [
        "ShadesCommands",
        "ShadesDocument",
        "ShadesEngine",
        "ShadesMCP",
        "ShadesMedia",
        "ShadesPlugins",
      ],
      swiftSettings: [.defaultIsolation(MainActor.self)],
    ),
    .target(name: "ShadesTestSupport", path: "Tests/ShadesTestSupport"),
    .testTarget(name: "ShadesCoreTests", dependencies: ["ShadesCore"]),
    .testTarget(name: "ShadesCaptionsTests", dependencies: ["ShadesCaptions", "ShadesTestSupport"]),
    .testTarget(name: "ShadesCommandsTests", dependencies: ["ShadesCommands"]),
    .testTarget(name: "ShadesDocumentTests", dependencies: ["ShadesDocument"]),
    .testTarget(name: "ShadesMediaTests", dependencies: ["ShadesMedia", "ShadesTestSupport"]),
    .testTarget(
      name: "ShadesEngineTests",
      dependencies: ["ShadesEngine", "ShadesTestSupport"],
      exclude: ["Golden"],
    ),
    .testTarget(
      name: "ShadesMCPTests",
      dependencies: ["ShadesMCP", "ShadesTestSupport"],
      exclude: ["Golden"],
    ),
    .testTarget(name: "ShadesPluginsTests", dependencies: ["ShadesPlugins"]),
    .testTarget(name: "ShadesUITests", dependencies: ["ShadesUI", "ShadesTestSupport"]),
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
