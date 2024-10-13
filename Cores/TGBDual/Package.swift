// swift-tools-version:6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "PVCoreTGBDual",
    platforms: [
        .iOS(.v17),
        .tvOS("15.4"),
        .watchOS(.v9),
        .macOS(.v11),
        .macCatalyst(.v17),
        .visionOS(.v1)
    ],
    products: [
        .library(
            name: "PVTGBDual",
            targets: ["PVTGBDual"]),
        .library(
            name: "PVTGBDual-Dynamic",
            type: .dynamic,
            targets: ["PVTGBDual"]),
        .library(
            name: "PVTGBDual-Static",
            type: .static,
            targets: ["PVTGBDual"]),

    ],
    dependencies: [
        .package(path: "../../PVCoreBridge"),
        .package(path: "../../PVCoreObjCBridge"),
        .package(path: "../../PVPlists"),
        .package(path: "../../PVEmulatorCore"),
        .package(path: "../../PVSupport"),
        .package(path: "../../PVAudio"),
        .package(path: "../../PVLogging"),
        .package(path: "../../PVObjCUtils"),

        .package(url: "https://github.com/Provenance-Emu/SwiftGenPlugin.git", branch: "develop"),
    ],
    targets: [
        
        // MARK: ------- Core ---------

        .target(
            name: "PVTGBDual",
            dependencies: [
                "PVEmulatorCore",
                "PVCoreBridge",
                "PVCoreObjCBridge",
                "PVLogging",
                "PVAudio",
                "PVSupport",
                "libtgbdual",
                "PVTGBDualCPP",
                "PVTGBDualBridge"
            ],
            resources: [
                .process("Resources/Core.plist")
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
            ],
            plugins: [
                // Disabled until SwiftGenPlugin support Swift 6 concurrency
                .plugin(name: "SwiftGenPlugin", package: "SwiftGenPlugin")
            ]
        ),
        
        // MARK: ------- Bridge ---------

        .target(
            name: "PVTGBDualBridge",
            dependencies: [
                "PVEmulatorCore",
                "PVCoreBridge",
                "PVCoreObjCBridge",
                "PVSupport",
                "PVPlists",
                "PVObjCUtils",
                "PVTGBDualCPP",
                "libtgbdual",
            ],
            cSettings: [
                .define("INLINE", to: "inline"),
                .define("USE_STRUCTS", to: "1"),
                .define("__LIBRETRO__", to: "1"),
                .define("HAVE_COCOATOUCH", to: "1"),
                .define("FRONTEND_SUPPORTS_RGB565", to: "1"),
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

        // MARK: ------- CPP Helpers ---------
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
                .define("HAVE_COCOATOUCH", to: "1"),
                .define("FRONTEND_SUPPORTS_RGB565", to: "1"),
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

        // MARK: ------- Emulator ---------

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
                .define("HAVE_COCOATOUCH", to: "1"),
                .define("FRONTEND_SUPPORTS_RGB565", to: "1"),
                .define("INLINE", to: "inline"),
                .define("USE_STRUCTS", to: "1"),
                .headerSearchPath("TGBDual/src/common/"),
            ],
            cxxSettings: [
                .define("__GCCUNIX__", to: "1"),
                .define("__LIB_RETRO__", to: "1"),
                .define("__LIBRETRO__", to: "1"),
                .define("HAVE_COCOATOUCH", to: "1"),
                .define("FRONTEND_SUPPORTS_RGB565", to: "1"),
                .define("INLINE", to: "inline"),
                .define("USE_STRUCTS", to: "1"),
                .headerSearchPath("include/"),
            ]
        ),

        // MARK: Tests
        .testTarget(
            name: "PVTGBDualTests",
            dependencies: [
                "PVTGBDual"])
    ],
    swiftLanguageModes: [.v5, .v6],
    cLanguageStandard: .gnu99,
    cxxLanguageStandard: .gnucxx20
)
