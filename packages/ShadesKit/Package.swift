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
        "ShadesAudio",
        "ShadesCaptions",
        "ShadesCommands",
        "ShadesDocument",
        "ShadesMedia",
        "ShadesEngine",
        "ShadesExport",
        "ShadesMatting",
        "ShadesMCP",
        "ShadesPlugins",
        "ShadesPolish",
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
    .target(name: "ShadesAudio", dependencies: ["ShadesCore", "ShadesMedia"]),
    .target(name: "ShadesPolish", dependencies: ["ShadesCore", "ShadesCommands"]),
    .target(name: "ShadesMatting", dependencies: ["ShadesCore"]),
    .target(
      name: "ShadesCaptions",
      dependencies: [
        "ShadesCore",
        "ShadesMedia",
        .product(name: "WhisperKit", package: "WhisperKit"),
      ],
    ),
    .target(name: "ShadesMedia", dependencies: ["ShadesCore"]),
    .target(name: "ShadesPlugins", dependencies: ["ShadesCore"]),
    .target(
      name: "ShadesEngine",
      dependencies: ["ShadesCore"],
      resources: [.copy("Shaders")],
    ),
    .target(name: "ShadesExport", dependencies: ["ShadesCaptions", "ShadesCore", "ShadesEngine"]),
    .target(
      name: "ShadesMCP",
      dependencies: [
        "ShadesCaptions",
        "ShadesExport",
        "ShadesMatting",
        "ShadesPolish",
        "ShadesCommands",
        "ShadesDocument",
        "ShadesEngine",
        "ShadesMedia",
        "ShadesPlugins",
      ],
    ),
    // ShadesUI sits above ShadesMCP (to show Claude's status) and runs on the main actor by
    // default; every other module is nonisolated.
    .target(
      name: "ShadesUI",
      dependencies: [
        "ShadesAudio",
        "ShadesCaptions",
        "ShadesCommands",
        "ShadesDocument",
        "ShadesEngine",
        "ShadesExport",
        "ShadesMCP",
        "ShadesMedia",
        "ShadesMatting",
        "ShadesPlugins",
        "ShadesPolish",
      ],
      swiftSettings: [.defaultIsolation(MainActor.self)],
    ),
    .target(
      name: "ShadesTestSupport",
      dependencies: ["ShadesCommands"],
      path: "Tests/ShadesTestSupport",
    ),
    .testTarget(name: "ShadesCoreTests", dependencies: ["ShadesCore"]),
    .testTarget(name: "ShadesAudioTests", dependencies: ["ShadesAudio", "ShadesTestSupport"]),
    .testTarget(name: "ShadesCaptionsTests", dependencies: ["ShadesCaptions", "ShadesTestSupport"]),
    .testTarget(name: "ShadesCommandsTests", dependencies: ["ShadesCommands"]),
    .testTarget(name: "ShadesDocumentTests", dependencies: ["ShadesDocument"]),
    .testTarget(name: "ShadesMediaTests", dependencies: ["ShadesMedia", "ShadesTestSupport"]),
    .testTarget(
      name: "ShadesEngineTests",
      dependencies: ["ShadesAudio", "ShadesEngine", "ShadesMatting", "ShadesTestSupport"],
      exclude: ["Golden"],
    ),
    .testTarget(
      name: "ShadesExportTests",
      dependencies: ["ShadesAudio", "ShadesExport", "ShadesTestSupport"],
    ),
    .testTarget(
      name: "ShadesMCPTests",
      dependencies: ["ShadesMCP", "ShadesTestSupport"],
      exclude: ["Golden"],
    ),
    .testTarget(
      name: "ShadesPluginsTests",
      dependencies: ["ShadesPlugins", "ShadesTestSupport"],
    ),
    .testTarget(name: "ShadesPolishTests", dependencies: ["ShadesPolish"]),
    .testTarget(name: "ShadesMattingTests", dependencies: ["ShadesMatting", "ShadesTestSupport"]),
    .testTarget(
      name: "ShadesUITests",
      dependencies: ["ShadesUI", "ShadesTestSupport"],
      exclude: ["Golden"],
    ),
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
