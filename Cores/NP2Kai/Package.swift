// swift-tools-version:5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "PVNP2Kai",
    platforms: [
        .iOS(.v13),
        .tvOS(.v13),
        .watchOS(.v9),
        .macOS(.v10_13),
        .macCatalyst(.v14)
    ],
    products: [
        // Products define the executables and libraries produced by a package, and make them visible to other packages.
        .library(
            name: "PVNP2Kai",
            targets: ["PVNP2Kai", "PVNP2KaiSwift"]),
    ],
    dependencies: [
        .package(path: "../../PVCoreBridge"),
        .package(path: "../../PVEmulatorCore"),
        .package(path: "../../PVSupport"),
        .package(path: "../../PVAudio"),
        .package(path: "../../PVLogging"),
        .package(path: "../../PVObjCUtils")
    ],
    targets: [
        .target(
            name: "PVNP2Kai",
            dependencies: [
                "libjaguar",
                "PVEmulatorCore",
                "PVCoreBridge",
                "PVSupport",
                "PVObjCUtils"
            ],
            path: "PVNP2Kai",
            publicHeadersPath: "include",
            cSettings: [
                .define("INLINE", to: "inline"),
                .define("USE_STRUCTS", to: "1"),
                .define("__LIBRETRO__", to: "1"),
                .define("HAVE_COCOATOJUCH", to: "1"),
                .define("__GCCUNIX__", to: "1"),
                .headerSearchPath("../libretro-np2kai/src"),
                .headerSearchPath("../libretro-np2kai/src/m68000"),
                .headerSearchPath("../libretro-np2kai/libretro-common"),
                .headerSearchPath("../libretro-np2kai/libretro-common/include"),
            ]
        ),

        .target(
            name: "PVNP2KaiSwift",
            dependencies: [
                "PVEmulatorCore",
                "PVCoreBridge",
                "PVLogging",
                "PVAudio",
                "PVSupport",
                "libjaguar",
                "PVNP2Kai"
            ],
            path: "PVNP2KaiSwift",
            cSettings: [
                .define("INLINE", to: "inline"),
                .define("USE_STRUCTS", to: "1"),
                .define("__LIBRETRO__", to: "1"),
                .define("HAVE_COCOATOJUCH", to: "1"),
                .define("__GCCUNIX__", to: "1"),
                .headerSearchPath("../libretro-np2kai/src"),
                .headerSearchPath("../libretro-np2kai/src/m68000"),
                .headerSearchPath("../libretro-np2kai/libretro-common"),
                .headerSearchPath("../libretro-np2kai/libretro-common/include"),
            ]
        ),

        .target(
            name: "libnp2kai",
            path: "libretro-np2kai",
            exclude: [
            ],
            sources: [

            ],
            publicHeadersPath: "src",
            packageAccess: true,
            cSettings: [
                .define("INLINE", to: "inline"),
                .define("USE_STRUCTS", to: "1"),
                .define("__LIBRETRO__", to: "1"),
                .define("HAVE_COCOATOJUCH", to: "1"),
                .define("__GCCUNIX__", to: "1"),
            ]
        )
    ],
    swiftLanguageVersions: [.v5],
    cLanguageStandard: .gnu11,
    cxxLanguageStandard: .gnucxx14
)
