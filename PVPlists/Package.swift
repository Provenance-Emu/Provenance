// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "PVPlists",
    platforms: [
        .iOS(.v17),
        .tvOS(.v17),
        .watchOS(.v9),
        .macOS(.v14),
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
        .package(path: "../PVLogging"),
        .package(path: "../PVPrimitives")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "PVPlists",
            dependencies: [
                "PVLogging",
                .product(name: "PVPrimitives", package: "PVPrimitives")
            ]
        ),
        .testTarget(
            name: "PVPlistsTests",
            dependencies: [
                "PVPlists",
                .product(name: "PVPrimitives", package: "PVPrimitives")
            ]
        ),
    ],
    swiftLanguageModes: [.v5, .v6]
)
