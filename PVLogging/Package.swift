// swift-tools-version:5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.
import PackageDescription

let package = Package(
    name: "PVLogging",
    platforms: [
        .iOS(.v11),
        .tvOS(.v11),
         .watchOS(.v7),
         .macOS(.v11)
    ],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "PVLogging",
            type: .dynamic,
            targets: ["PVLogging", "PVLoggingObjC"]),
        .library(
            name: "PVLogging-Static",
            type: .static,
            targets: ["PVLogging", "PVLoggingObjC"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        .package(
            url: "https://github.com/CocoaLumberjack/CocoaLumberjack",
            .upToNextMajor(from: "3.8.0")),
        .package(url: "https://github.com/fpillet/NSLogger", branch: "master")
    ],
    targets: [
         .target(
             name: "PVLoggingObjC",
             dependencies: [
                .product(name: "CocoaLumberjack", package: "CocoaLumberjack"),
                 .product(name: "CocoaLumberjackSwift", package: "CocoaLumberjack"),
                 .product(name: "CocoaLumberjackSwiftLogBackend", package: "CocoaLumberjack"),
                 "NSLogger"
             ],
             path: "Sources/ObjC",
             publicHeadersPath: "include"),

        .target(
            name: "PVLogging",
            dependencies: [
                "PVLoggingObjC",
                .product(name: "CocoaLumberjack", package: "CocoaLumberjack"),
                .product(name: "CocoaLumberjackSwift", package: "CocoaLumberjack"),
                .product(name: "CocoaLumberjackSwiftLogBackend", package: "CocoaLumberjack"),
                "NSLogger"
            ],
            path: "Sources/Swift",
            publicHeadersPath: "include"),
        // MARK: SwiftPM tests
        .testTarget(
            name: "PVLoggingTests",
            dependencies: ["PVLogging"],
            path: "Tests")
    ]
)
