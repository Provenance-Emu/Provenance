// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PVHelp",
    platforms: [
        .iOS(.v16),
        .tvOS(.v16),
        .watchOS(.v9),
        .macOS(.v13),
        .macCatalyst(.v16),
        .visionOS(.v1)
    ],
    products: [
        .library(
            name: "PVHelp",
            targets: ["PVHelp"]),
    ],
    dependencies: [
        .package(path: "../PVLogging"),
    ],
    targets: [
        .target(
            name: "PVHelp",
            dependencies: ["PVLogging"],
            resources: [.process("Resources")]),
        .testTarget(
            name: "PVHelpTests",
            dependencies: ["PVHelp"]),
    ],
    swiftLanguageModes: [.v5]
)
