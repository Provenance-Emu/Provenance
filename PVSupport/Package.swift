// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.
import PackageDescription

let package = Package(
    name: "PVSupport",
    platforms: [
        .iOS(.v11),
        .tvOS(.v11),
        // .watchOS(.v7),
        // .macOS(.v11)
    ],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "PVSupport",
            targets: ["PVSupport"]),
        .library(
            name: "PVSupport-ObjC",
            targets: ["PVSupport-ObjC"]),
        .library(
            name: "PVAudio",
            targets: ["PVAudio"]),
//        .library(
//            name: "PVLogging-ObjC",
//            targets: ["PVLogging-ObjC"]),
        .library(
            name: "PVLogging",
            targets: ["PVLogging"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        .package(
            url: "https://github.com/CocoaLumberjack/CocoaLumberjack.git",
            .upToNextMajor(from: "3.7.2")),
        .package(
            url: "https://github.com/fpillet/NSLogger.git",
            .branch("master")),
        .package(
            name: "Reachability",
            url: "https://github.com/ashleymills/Reachability.swift",
            .upToNextMajor(from: "5.1.0"))
    ],
    targets: [

        .target(
            name: "PVAudio",
            dependencies: [],
            path: "Sources/PVAudio",
            publicHeadersPath: "Public Headers"),

//        .target(
//            name: "PVLoggingObjC",PVCocoaLumberJackLogging
//            dependencies: [.product(name: "CocoaLumberjack", package: "CocoaLumberjack")],
//            path: "Sources/PVLogging/ObjC"),
//
//        .target(
//            name: "PVLogging-ObjC",
//            dependencies: [
//                .product(name: "CocoaLumberjack", package: "CocoaLumberjack"),
//                .product(name: "CocoaLumberjackSwift", package: "CocoaLumberjack"),
//                .product(name: "CocoaLumberjackSwiftLogBackend", package: "CocoaLumberjack")
//            ],
//            path: "Sources/PVLogging-ObjC"),
        
        .target(
            name: "PVLogging",
            dependencies: [
                .product(name: "CocoaLumberjack", package: "CocoaLumberjack"),
                "NSLogger"
//                .product(name: "CocoaLumberjack", package: "CocoaLumberjackSwift")
            ],
            path: "Sources/PVLogging"),

        .target(
            name: "PVSupport-ObjC",
            dependencies: ["PVLogging", "PVAudio"],
            path: "Sources/PVSupport-ObjC",
            publicHeadersPath: "Public Headers"),

        .target(
            name: "PVSupport",
            dependencies: [
                "PVSupport-ObjC",
                .product(name: "CocoaLumberjack", package: "CocoaLumberjack"),
                .product(name: "CocoaLumberjackSwift", package: "CocoaLumberjack"),
                .product(name: "CocoaLumberjackSwiftLogBackend", package: "CocoaLumberjack"),
                "Reachability"],
            resources: [
//                .process("Resources/AHAP/")
            ]),
            // publicHeadersPath: "include"),

        // MARK: SwiftPM tests
        .testTarget(
            name: "PVSupportTests",
            dependencies: ["PVSupport"]),
    ]
)
