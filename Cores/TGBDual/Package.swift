// swift-tools-version:5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "PVTGBDual",
    platforms: [
        .iOS(.v13),
        .tvOS(.v13),
        .watchOS(.v9),
        .macOS(.v11),
        .macCatalyst(.v14),
        .visionOS(.v1)
    ],
    products: [
        .library(
            name: "PVTGBDual",
            targets: ["PVTGBDual", "PVTGBDualSwift"]),
        .library(
            name: "PVTGBDual-Dynamic",
            type: .dynamic,
            targets: ["PVTGBDual", "PVTGBDualSwift"]),
        .library(
            name: "PVTGBDual-Static",
            type: .static,
            targets: ["PVTGBDual", "PVTGBDualSwift"]),

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
            name: "PVTGBDual",
            dependencies: [
                "PVEmulatorCore",
                "PVCoreBridge",
                "PVSupport",
                "PVObjCUtils",
                "PVTGBDualSwift",
                "PVTGBDualCPP",
                "libtgbdual",
            ],
            resources: [
                .process("Resources/Core.plist")
            ],
            publicHeadersPath: "include",
            cSettings: [
                .define("INLINE", to: "inline"),
                .define("USE_STRUCTS", to: "1"),
                .define("__LIBRETRO__", to: "1"),
                .define("HAVE_COCOATOJUCH", to: "1"),
                .define("__GCCUNIX__", to: "1"),
                .headerSearchPath("../libTGBDual/TGBDual/src/os/libretro/"),
            ],
            cxxSettings: [
                .unsafeFlags([
                    "-fmodules",
                    "-fcxx-modules"
                ]),
                .define("INLINE", to: "inline"),
                .define("USE_STRUCTS", to: "1"),
                .define("__LIBRETRO__", to: "1"),
                .define("HAVE_COCOATOJUCH", to: "1"),
                .define("__GCCUNIX__", to: "1"),
                .headerSearchPath("../libTGBDual/TGBDual/src/os/libretro/"),
            ],
            swiftSettings: [
                .interoperabilityMode(.Cxx)
            ]
        ),

        .target(
            name: "PVTGBDualSwift",
            dependencies: [
                "PVEmulatorCore",
                "PVCoreBridge",
                "PVLogging",
                "PVAudio",
                "PVSupport",
                "libtgbdual",
                "PVTGBDualCPP"
            ],
            cSettings: [
                .define("INLINE", to: "inline"),
                .define("USE_STRUCTS", to: "1"),
                .define("__LIBRETRO__", to: "1"),
                .define("HAVE_COCOATOJUCH", to: "1"),
                .define("__GCCUNIX__", to: "1"),
                .headerSearchPath("../libTGBDual/TGBDual/src/os/libretro/"),
            ],
            cxxSettings: [
                .define("INLINE", to: "inline"),
                .define("USE_STRUCTS", to: "1"),
                .define("__LIBRETRO__", to: "1"),
                .define("HAVE_COCOATOJUCH", to: "1"),
                .define("__GCCUNIX__", to: "1"),
                .headerSearchPath("../libTGBDual/TGBDual/src/os/libretro/"),
            ],
            swiftSettings: [
                .interoperabilityMode(.Cxx)
            ]
        ),

        .target(
            name: "PVTGBDualCPP",
            dependencies: [
                "libtgbdual",
            ],
            publicHeadersPath: "./",
            cSettings: [
                .define("INLINE", to: "inline"),
                .define("USE_STRUCTS", to: "1"),
                .define("__LIBRETRO__", to: "1"),
                .define("HAVE_COCOATOJUCH", to: "1"),
                .define("__GCCUNIX__", to: "1"),
                .headerSearchPath("../libTGBDual/TGBDual/src/os/libretro/"),
            ],
            cxxSettings: [
                .define("INLINE", to: "inline"),
                .define("USE_STRUCTS", to: "1"),
                .define("__LIBRETRO__", to: "1"),
                .define("HAVE_COCOATOJUCH", to: "1"),
                .define("__GCCUNIX__", to: "1"),
                .headerSearchPath("../libTGBDual/TGBDual/src/os/libretro/"),
            ]
        ),

        .target(
            name: "libtgbdual",
            sources: [
                "tgbdual-emulator/gb_core/apu.cpp",
                "tgbdual-emulator/gb_core/cheat.cpp",
                "tgbdual-emulator/gb_core/cpu.cpp",
                "tgbdual-emulator/gb_core/gb.cpp",
                "tgbdual-emulator/gb_core/lcd.cpp",
                "tgbdual-emulator/gb_core/mbc.cpp",
                "tgbdual-emulator/gb_core/rom.cpp",
                "tgbdual-emulator/gbr_interface/gbr.cpp",
                "tgbdual-emulator/libretro/dmy_renderer.cpp",
                "tgbdual-emulator/libretro/libretro.cpp",
            ],
            packageAccess: true,
            cSettings: [
                .define("__GCCUNIX__", to: "1"),
                .define("__LIB_RETRO__", to: "1"),
                .define("__LIBRETRO__", to: "1"),
                .define("HAVE_COCOATOJUCH", to: "1"),
                .define("INLINE", to: "inline"),
                .define("USE_STRUCTS", to: "1"),
                .headerSearchPath("TGBDual/src/common/"),
            ],
            cxxSettings: [
                .define("__GCCUNIX__", to: "1"),
                .define("__LIB_RETRO__", to: "1"),
                .define("__LIBRETRO__", to: "1"),
                .define("HAVE_COCOATOJUCH", to: "1"),
                .define("INLINE", to: "inline"),
                .define("USE_STRUCTS", to: "1"),
                .headerSearchPath("include/"),
            ]
        )
    ],
    swiftLanguageVersions: [.v5],
    cLanguageStandard: .gnu99,
    cxxLanguageStandard: .gnucxx17
)
