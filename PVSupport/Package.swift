// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.
import PackageDescription

let package = Package(
    name: "PVSupport",
    platforms: [
        .iOS(.v13),
        .tvOS(.v13),
        // .watchOS(.v8),
        // .macOS(.v11)
    ],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "PVSupport",
            targets: ["PVSupport"]),
        .library(
            name: "PVSupportObjC",
            targets: ["PVSupportObjC"])
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        .package(
            url: "https://github.com/CocoaLumberjack/CocoaLumberjack",
            .upToNextMajor(from: "3.7.2")),
        .package(
            name: "Reachability",
            url: "https://github.com/ashleymills/Reachability.swift",
            .upToNextMajor(from: "5.1.0")),
        .package(
            url: "https://github.com/fpillet/NSLogger",
            .branch("master"))
    ],
    targets: [
        .target(
            name: "PVSupportObjC",
            dependencies: [.product(name: "CocoaLumberjack", package: "CocoaLumberjack")],
            path: "Sources/PVSupportObjc"),
        .target(
            name: "PVSupport",
            dependencies: [
                "PVSupportObjC",
                .product(name: "CocoaLumberjack", package: "CocoaLumberjack"),
                .product(name: "CocoaLumberjackSwift", package: "CocoaLumberjack"),
                .product(name: "CocoaLumberjackSwiftLogBackend", package: "CocoaLumberjack"),
                "NSLogger",
                "Reachability"],
            path: "Sources/PVSupport",
            // exclude: [
            //     "EmulatorCore/PVEmulatorCore.m",
            //     "Info.plist",
            //     "MASShortcut.modulemap",
            //     "Prefix.pch"
            // ],
            resources: [
                .process("Controller/AHAP/")
            ]),
            // publicHeadersPath: "include"),

        // MARK: SwiftPM tests
        .testTarget(
            name: "PVSupportTests",
            dependencies: ["PVSupport"])
    ]
)
