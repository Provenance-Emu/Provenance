// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "PVPlists",
    platforms: [
        .iOS(.v16),
        .tvOS(.v16),
        .watchOS(.v9),
        .macOS(.v11),
        .macCatalyst(.v17),
        .visionOS(.v1)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "PVPlists",
            targets: ["PVPlists"]),
    ],
    dependencies: [
        .package(path: "../PVLogging")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "PVPlists",
            dependencies: [
                "PVLogging"
            ]
        ),
        .testTarget(
            name: "PVPlistsTests",
            dependencies: ["PVPlists"]
        ),
    ],
    swiftLanguageModes: [.v5, .v6]
)
