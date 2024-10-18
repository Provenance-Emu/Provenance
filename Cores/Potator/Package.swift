// swift-tools-version:5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "PVPotator",
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
            name: "PVPotator",
            targets: ["PVPotator", "PVPotatorSwift"]),
    ],
    dependencies: [
        .package(path: "../../PVCoreBridge"),
        .package(path: "../../PVEmulatorCore"),
        .package(path: "../../PVSupport"),
        .package(path: "../../PVAudio"),
        .package(path: "../../PVLogging"),
        .package(path: "../../PVObjCUtils"),
        .package(path: "../../PVLibRetro")
    ],
    targets: [
        .target(
            name: "PVPotator",
            dependencies: [
                "libpotator",
                "PVEmulatorCore",
                "PVCoreBridge",
                "PVSupport",
                "PVLibRetro",
                "PVObjCUtils",
                "PVPotatorSwift"
            ],
            path: "PVPotatorCore",
            publicHeadersPath: "include",
            cSettings: [
                .define("INLINE", to: "inline"),
                .define("USE_STRUCTS", to: "1"),
                .define("__LIBRETRO__", to: "1"),
                .define("HAVE_COCOATOJUCH", to: "1"),
                .define("__GCCUNIX__", to: "1"),
                .headerSearchPath("../potator/common/"),
                .headerSearchPath("../potator/common/m6502"),
                .headerSearchPath("../potator/platform/libretro"),
                .headerSearchPath("../potator/platform/libretro/libretro-common"),
                .headerSearchPath("../potator/platform/libretro/libretro-common/include")
            ]
        ),

        .target(
            name: "PVPotatorSwift",
            dependencies: [
                "PVEmulatorCore",
                "PVCoreBridge",
                "PVLogging",
                "PVAudio",
                "PVSupport",
                "libpotator",
                "PVLibRetro",
            ],
            path: "PVPotatorSwift",
            cSettings: [
                .define("INLINE", to: "inline"),
                .define("USE_STRUCTS", to: "1"),
                .define("__LIBRETRO__", to: "1"),
                .define("HAVE_COCOATOJUCH", to: "1"),
                .define("__GCCUNIX__", to: "1"),
                .headerSearchPath("../Potator-libretro/src"),
                .headerSearchPath("../Potator-libretro/src/m68000"),
                .headerSearchPath("../Potator-libretro/libretro-common"),
                .headerSearchPath("../Potator-libretro/libretro-common/include"),
            ]
        ),

        .target(
            name: "libpotator",
            path: "potator",
            exclude: [
            ],
            sources: [
               "common/controls.c",
               "common/gpu.c",
               "common/memorymap.c",
               "common/sound.c",
               "common/timer.c",
               "common/watara.c",
               "common/m6502/m6502.c"
            ],
            publicHeadersPath: "./",
            packageAccess: true,
            cSettings: [
                .headerSearchPath("./common/"),
                .headerSearchPath("./common/m6502"),
                .headerSearchPath("./platform/libretro"),
                .headerSearchPath("./platform/libretro/libretro-common")
            ]
        )
    ],
    swiftLanguageVersions: [.v5],
    cLanguageStandard: .gnu11,
    cxxLanguageStandard: .gnucxx14
)
