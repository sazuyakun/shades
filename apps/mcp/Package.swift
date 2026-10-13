// swift-tools-version: 6.2
import PackageDescription

let package = Package(
  name: "ShadesMCPRelay",
  platforms: [.macOS(.v15)],
  products: [.executable(name: "shades-mcp", targets: ["ShadesMCPRelay"])],
  targets: [
    .executableTarget(
      name: "ShadesMCPRelay",
      path: "Sources",
      swiftSettings: [
        .defaultIsolation(MainActor.self),
        .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
        .enableUpcomingFeature("InferIsolatedConformances"),
      ],
    )
  ],
)
