// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "HueModelHarness",
    dependencies: [.package(path: "product/ios/Packages/HueBoardKit")],
    targets: [
        .target(name: "CryptoKit"),
        .target(name: "Hue_Board", dependencies: [
            "CryptoKit",
            .product(name: "HueBoardKit", package: "HueBoardKit"),
            .product(name: "HueBoardNativeCore", package: "HueBoardKit"),
            .product(name: "HueBoardAppleEngine", package: "HueBoardKit")
        ]),
        .testTarget(name: "HueModelTests", dependencies: ["Hue_Board"])
    ],
    swiftLanguageModes: [.v6]
)
