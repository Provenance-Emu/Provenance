// swift-tools-version:5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.
import PackageDescription

let package = Package(
    name: "PVLogging",
    platforms: [
        .iOS(.v13),
        .tvOS(.v13),
        .watchOS(.v7),
        .macOS(.v11)
    ],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "PVLogging",
            type: .dynamic,
            targets: ["PVLogging"]),
        .library(
            name: "PVLogging-Dynamic",
            type: .dynamic,
            targets: ["PVLogging"]),
        .library(
            name: "PVLogging-Static",
            type: .static,
            targets: ["PVLogging"])
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
            publicHeadersPath: "include/"
        ),

        .target(
            name: "PVLogging",
            dependencies: [
                .product(name: "CocoaLumberjack", package: "CocoaLumberjack"),
                .product(name: "CocoaLumberjackSwift", package: "CocoaLumberjack"),
                .product(name: "CocoaLumberjackSwiftLogBackend", package: "CocoaLumberjack"),
                "NSLogger",
                "PVLoggingObjC"
            ],
            publicHeadersPath: "include/"
            //            ,
            //            cSettings: [
            //                .headerSearchPath("."),
            //                .headerSearchPath("include"),
            //                .headerSearchPath("include/PVLogging"),
            //            ]
            // This breaks ObjC Cocoalumberjack to Swift bindings for option types
            //                swiftSettings: [
            //                    .unsafeFlags([
            //                        "-Xfrontend", "-enable-cxx-interop",
            //                        //                    "-Xfrontend", "-validate-tbd-against-ir=none",
            //                        //                    "-I", "Sources/CXX/include",
            //                        //                    "-I", "\(sdkRoot)/usr/include",
            //                        //                    "-I", "\(cPath)",
            //                        //                    "-lc++",
            //                        //                    "-Xfrontend", "-disable-implicit-concurrency-module-import",
            //                        //                    "-Xcc", "-nostdinc++"
            //                    ])
            //                ]
        ),

        // MARK: SwiftPM tests
        .testTarget(
            name: "PVLoggingTests",
            dependencies: ["PVLogging"],
            path: "Tests")
    ],
    swiftLanguageVersions: [.v5],
    cLanguageStandard: .c17,
    cxxLanguageStandard: .cxx17
)
