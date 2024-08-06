// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "bzip2",
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "bzip2",
            targets: ["bzip2"]),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "bzip2",
            linkerSettings: [
                .linkedLibrary("bz2"),
            ]
        ),
        .testTarget(
            name: "bzip2Tests",
            dependencies: ["bzip2"]
        ),
    ]
)
