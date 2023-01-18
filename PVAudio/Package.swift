// swift-tools-version:5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.
import PackageDescription

let package = Package(
    name: "PVAudio",
    platforms: [
        .iOS(.v13),
        .tvOS(.v13),
        .watchOS(.v7),
        .macOS(.v11)
    ],
    products: [
        .library(
            name: "PVAudio",
            targets: ["PVAudio"]),
         .library(
             name: "PVAudio-Dynamic",
             type: .dynamic,
             targets: ["PVAudio"]),
         .library(
             name: "PVAudio-Static",
             type: .static,
             targets: ["PVAudio"])
    ],

    dependencies: [
        // Dependencies declare other packages that this package depends on.
        .package(name: "PVLogging", path: "../PVLogging/"),
        .package(name: "PVSupport", path: "../PVSupport/"),
        .package(name: "PVObjCUtils", path: "../PVObjCUtils/")
    ],

    // MARK: - Targets
    targets: [
        // MARK: - PVAudio
        .target(
            name: "PVAudio",
            dependencies: [
                .product(name: "PVSupport", package: "PVSupport"),
                .product(name: "PVLogging", package: "PVLogging"),
                .product(name: "PVObjCUtils", package: "PVObjCUtils")
            ],
            publicHeadersPath: "include",
            cSettings: [
                .define("LIBRETRO", to: "1"),
                .headerSearchPath("include"),
                .headerSearchPath("../PVSupport/include"),
                .headerSearchPath("../PVAudioObjC/include")
            ],
            swiftSettings: [
                .define("LIBRETRO"),
                .unsafeFlags([
                    "-Xfrontend", "-enabled-cxx-interop"
                ])
            ],
            linkerSettings: [
                .linkedFramework("GameController", .when(platforms: [.iOS, .tvOS])),
                .linkedFramework("CoreGraphics", .when(platforms: [.iOS, .tvOS])),
                .linkedFramework("UIKit", .when(platforms: [.iOS, .tvOS])),
                .linkedFramework("WatchKit", .when(platforms: [.watchOS]))
            ])],
    cLanguageStandard: .c11,
    cxxLanguageStandard: .cxx17
)
