// swift-tools-version: 6.2
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
        .library(name: "HueBoardAppleEngine", targets: ["HueBoardAppleEngine"]),
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
        .target(
            name: "HueBoardAppleEngine",
            dependencies: ["HueBoardKit"],
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "HueBoardKitTests",
            dependencies: ["HueBoardKit"]
        ),
        .testTarget(
            name: "HueBoardNativeCoreTests",
            dependencies: ["HueBoardNativeCore", "HueBoardKit"]
        ),
        .testTarget(
            name: "HueBoardAppleEngineTests",
            dependencies: ["HueBoardAppleEngine", "HueBoardKit"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
