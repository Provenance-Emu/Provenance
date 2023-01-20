// swift-tools-version:5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.
import PackageDescription
import Foundation

#if os(Linux)
import Glibc
#else
import Darwin.C
#endif

let cxxSettings: [CXXSetting] = [
    .headerSearchPath("."),
    .headerSearchPath("include"),
    .headerSearchPath("$GENERATED_MODULEMAP_DIR"),
]

let cSettings: [CSetting] = [
    .headerSearchPath("."),
    .headerSearchPath("include"),
    .headerSearchPath("$GENERATED_MODULEMAP_DIR"),
]

let unsafeFlags: SwiftSetting = .unsafeFlags([
    "-enable-experimental-cxx-interop",
//    "-Xfrontend", "-enable-experimental-cxx-interop",
//    "-Xfrontend", "-enable-experimental-cxx-interop-in-clang-header"
//    "-enable-experimental-cxx-interop-in-clang-header",
//    "-Xfrontend", "-enable-cxx-interop",
//    "-Xfrontend", "-Xcc",
//    "-enable-cxx-interop",
//    "-Xfrontend", "-enable-cxx-interop",
//    "-Xfrontend", "-validate-tbd-against-ir=none",
//    "-I", "Sources/CXX/include",
//    "-I", "\(sdkRoot)/usr/include",
//    "-I", "\(cPath)",
//    "-lc++",
//    "-Xfrontend", "-disable-implicit-concurrency-module-import",
//    "-Xcc", "-nostdinc++"
])

let swiftSettings: [SwiftSetting] = [
    .define("LIBRETRO"),
    unsafeFlags
]

//guard let GENERATED_MODULEMAP_DIR = getenv("GENERATED_MODULEMAP_DIR") else { //ProcessInfo.processInfo.environment["GENERATED_MODULEMAP_DIR"] else {
//    print("\(ProcessInfo.processInfo.environment.keys.joined(separator: "\n"))")
//    fatalError("Could not find $GENERATED_MODULEMAP_DIR")
//}
//
//guard let cPath = ProcessInfo.processInfo.environment["CPATH"] else {
//    fatalError("Could not find CPATH")
//}

let package = Package(
    name: "PVEmulatorCore",
    platforms: [
        .iOS(.v13),
        .tvOS(.v13),
        .watchOS(.v7),
        .macOS(.v11)
    ],
    products: [
        .library(
            name: "PVEmulatorCore",
            targets: ["PVEmulatorCore", "PVEmulatorCoreObjC", "PVEmulatorCoreSwift"]),
        //        .library(
        //            name: "PVEmulatorCoreSwift",
        //            targets: ["PVEmulatorCore", "PVEmulatorCoreSwift"]),
//     .library(
//         name: "PVEmulatorCore-Dynamic",
//         type: .dynamic,
//         targets: ["PVEmulatorCore"]),
        //         .library(
        //             name: "PVEmulatorCore-Static",
        //             type: .static,
        //             targets: ["PVEmulatorCore", "PVEmulatorCoreObjC"])
    ],

    dependencies: [
        // Dependencies declare other packages that this package depends on.
        .package(name: "PVLogging", path: "../PVLogging/"),
        .package(name: "PVSupport", path: "../PVSupport/"),
        .package(name: "PVObjCUtils", path: "../PVObjCUtils/"),
        .package(name: "PVAudio", path: "../PVAudio/")
    ],

    // MARK: - Targets
    targets: [
        // MARK: - PVEmulatorCore
        .target(
            name: "PVEmulatorCore",
            dependencies: [
                "PVEmulatorCoreObjC", "PVEmulatorCoreSwift"
            ],
            publicHeadersPath: "include",
            cSettings: cSettings,
            cxxSettings: cxxSettings,
            swiftSettings: swiftSettings
        ),

            .target(
                name: "PVEmulatorCoreObjC",
                dependencies: [
                    .product(name: "PVObjCUtils", package: "PVObjCUtils"),
                    .product(name: "PVSupport", package: "PVSupport"),
                    .product(name: "PVLogging", package: "PVLogging"),
                    .product(name: "PVAudio", package: "PVAudio")
                ],
                publicHeadersPath: "include",
                cSettings: [
                    .headerSearchPath("$GENERATED_MODULEMAP_DIR"),
                    .headerSearchPath("include")
                ],
                cxxSettings: [
                    .headerSearchPath("$GENERATED_MODULEMAP_DIR"),
                    .headerSearchPath("include")
                ],
                swiftSettings: swiftSettings,
                linkerSettings: [
                    .linkedFramework("GameController", .when(platforms: [.iOS, .tvOS])),
                    .linkedFramework("CoreGraphics", .when(platforms: [.iOS, .tvOS])),
                    .linkedFramework("UIKit", .when(platforms: [.iOS, .tvOS])),
                    .linkedFramework("WatchKit", .when(platforms: [.watchOS]))
                ]
            ),

            .target(
                name: "PVEmulatorCoreSwift",
                dependencies: [
                    "PVEmulatorCoreObjC",
                    .product(name: "PVSupport", package: "PVSupport"),
                    .product(name: "PVAudio", package: "PVAudio"),
                    .product(name: "PVLogging", package: "PVLogging")
                ],
                //            publicHeadersPath: "include",
                cSettings: [
                    .define("LIBRETRO", to: "1"),
                    .headerSearchPath("$GENERATED_MODULEMAP_DIR"),
                    .headerSearchPath("include"),
                    .headerSearchPath("../PVEmulatorCoreObjC/include")
                ],
                cxxSettings: [
                    .define("LIBRETRO", to: "1"),
                    .headerSearchPath("include"),
                    .headerSearchPath("$GENERATED_MODULEMAP_DIR"),
                    //                .headerSearchPath("../PVSupport/include"),
                    .headerSearchPath("../PVEmulatorCoreObjC/include")
                ],
                swiftSettings: swiftSettings,
                linkerSettings: [
                    .linkedFramework("GameController", .when(platforms: [.iOS, .tvOS])),
                    .linkedFramework("CoreGraphics", .when(platforms: [.iOS, .tvOS])),
                    .linkedFramework("UIKit", .when(platforms: [.iOS, .tvOS])),
                    .linkedFramework("WatchKit", .when(platforms: [.watchOS]))
                ])],
    cLanguageStandard: .c17,
    cxxLanguageStandard: .cxx20
)

