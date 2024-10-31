// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "minizip",
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "minizip",
            targets: ["minizip"]),
    ],
    dependencies: [
        .package(path: "../bzip2")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "minizip",
            dependencies: ["bzip2"],
            cSettings: [
                .headerSearchPath("bzip2"),
                .define("HAVE_BZIP2", to: "1"),
            ],
            linkerSettings: [
                .linkedLibrary("z"),
            ]
        ),

        .testTarget(
            name: "minizipTests",
            dependencies: ["minizip"]
        ),
    ]
)
