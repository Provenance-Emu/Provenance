// swift-tools-version:5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.
import PackageDescription

let package = Package(
    name: "PVObjCUtils",
    platforms: [
        .iOS(.v13),
        .tvOS(.v13),
        .watchOS(.v7),
        .macOS(.v11)
    ],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "PVObjCUtils",
            targets: ["PVObjCUtils"]),
        .library(
            name: "PVObjCUtils-Dynamic",
            type: .dynamic,
            targets: ["PVObjCUtils"]),
        .library(
            name: "PVObjCUtils-Static",
            type: .static,
            targets: ["PVObjCUtils"])
    ],

    dependencies: [],

    // MARK: - Targets
    targets: [
        // MARK: - PVObjCUtils
        .target(
            name: "PVObjCUtils",
            dependencies: [
            ],
            publicHeadersPath: "include"
        )
    ]
)
