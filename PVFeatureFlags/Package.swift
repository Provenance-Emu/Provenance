// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "PVFeatureFlags",
    platforms: [
        .iOS(.v17),
        .macOS(.v13),
        .tvOS(.v17),
        .watchOS(.v9),
        .visionOS(.v1),
        .macCatalyst(.v17)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "PVFeatureFlags",
            targets: ["PVFeatureFlags"]),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "PVFeatureFlags",
            resources: [.process("Resources")]),
        .testTarget(
            name: "PVFeatureFlagsTests",
            dependencies: ["PVFeatureFlags"]
        ),
    ]
)
