// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "HueBoardKit",
  platforms: [
    .iOS(.v18),
    .macOS(.v15),
  ],
  products: [
    .library(name: "HueBoardKit", targets: ["HueBoardKit"]),
    .library(name: "HueBoardNativeCore", targets: ["HueBoardNativeCore"]),
  ],
  targets: [
    .target(
      name: "HueBoardKit",
      resources: [.process("Resources")]
    ),
    .target(
      name: "HueBoardNativeCore",
      dependencies: ["HueBoardKit"]
    ),
    .testTarget(
      name: "HueBoardKitTests",
      dependencies: ["HueBoardKit"]
    ),
    .testTarget(
      name: "HueBoardNativeCoreTests",
      dependencies: ["HueBoardKit", "HueBoardNativeCore"]
    ),
  ]
)
