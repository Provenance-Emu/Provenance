// swift-tools-version:6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let INLINE = "inline"
let NO_ZIP = "0"
let __GCCUNIX__ = "1"
let __LIBRETRO__ = "1"

let VIDEO_UPSCALE = "1"


let package = Package(
    name: "PVPokeMini",
    platforms: [
        .iOS(.v17),
        .tvOS("15.4"),
        .watchOS(.v9),
        .macOS(.v11),
        .macCatalyst(.v17),
        .visionOS(.v1)
    ],
    products: [
        // Products define the executables and libraries produced by a package, and make them visible to other packages.
        .library(
            name: "PVPokeMini",
            targets: ["PVPokeMini"]),
        .library(
            name: "PVPokeMini-Dynamic",
            type: .dynamic,
            targets: ["PVPokeMini"]),
        .library(
            name: "PVPokeMini-Static",
            type: .static,
            targets: ["PVPokeMini"])
    ],
    dependencies: [
        .package(path: "../../PVCoreBridge"),
        .package(path: "../../PVCoreObjCBridge"),
        .package(path: "../../PVPlists"),
        .package(path: "../../PVEmulatorCore"),
        .package(path: "../../PVAudio"),
        .package(path: "../../PVLogging"),
        .package(path: "../../PVObjCUtils"),

        .package(url: "https://github.com/Provenance-Emu/SwiftGenPlugin.git", branch: "develop"),
    ],
    targets: [
        // --------- Core ---------
        .target(
            name: "PVPokeMini",
            dependencies: [
                "PVEmulatorCore",
                "PVCoreBridge",
                "PVLogging",
                "PVAudio",
                "PVPokeMiniBridge",
                "libpokemini",
                "PokeMiniC",
                "PVPokeMiniOptions"
            ],
            resources: [
                .process("Resources/Core.plist")
            ],
            cSettings: [
                .define("INLINE", to: INLINE),
                .define("NO_ZIP", to: NO_ZIP),
                .define("VIDEO_UPSCALE", to: VIDEO_UPSCALE),
            ],
            plugins: [
                .plugin(name: "SwiftGenPlugin", package: "SwiftGenPlugin")
            ]
        ),
        // --------- Bridge ---------
        .target(
            name: "PVPokeMiniBridge",
            dependencies: [
                "PVEmulatorCore",
                "PVCoreBridge",
                "PVCoreObjCBridge",
                "PVObjCUtils",
                "PVLogging",
                "PVPlists",
                "PokeMiniC",
                "libpokemini",
                "PVPokeMiniOptions"
            ],
            cSettings: [
                .define("INLINE", to: INLINE),
                .define("NO_ZIP", to: NO_ZIP),
                .define("__GCCUNIX__", to: __GCCUNIX__),
                .define("__LIBRETRO__", to: __LIBRETRO__),
                .define("VIDEO_UPSCALE", to: VIDEO_UPSCALE),
            ]
        ),
        // --------- Options ---------
        .target(
            name: "PVPokeMiniOptions",
            dependencies: [
                "PVEmulatorCore",
                "PVCoreBridge",
                "PVCoreObjCBridge",
                "PVObjCUtils",
                "PVLogging",
                "PVPlists",
                "PokeMiniC",
                "libpokemini"
            ]
        ),
        // --------- C Helpers ---------
        .target(
            name: "PokeMiniC",
            dependencies: [
                "PVEmulatorCore",
                "PVCoreBridge",
                "PVLogging",
                "PVAudio",
                "libpokemini",
            ],
            packageAccess: true,
            cSettings: [
                .define("INLINE", to: INLINE),
                .define("NO_ZIP", to: NO_ZIP),
                .define("__GCCUNIX__", to: __GCCUNIX__),
                .define("__LIBRETRO__", to: __LIBRETRO__),
                .define("VIDEO_UPSCALE", to: VIDEO_UPSCALE),
            ]
        ),

        // --------- Emulator ---------

        .target(
            name: "libpokemini",
            exclude: [
            ],
            sources: [
                "PokeMini-libretro/freebios/freebios.c",
                "PokeMini-libretro/resource/PokeMini_BG2.c",
                "PokeMini-libretro/resource/PokeMini_BG3.c",
                "PokeMini-libretro/resource/PokeMini_BG4.c",
                "PokeMini-libretro/resource/PokeMini_BG5.c",
                "PokeMini-libretro/resource/PokeMini_BG6.c",
                "PokeMini-libretro/resource/PokeMini_ColorPal.c",
                "PokeMini-libretro/resource/PokeMini_Font12.c",
                "PokeMini-libretro/resource/PokeMini_Icons12.c",
                "PokeMini-libretro/source/CommandLine.c",
                "PokeMini-libretro/source/Hardware.c",
                "PokeMini-libretro/source/Joystick.c",
                "PokeMini-libretro/source/MinxAudio.c",
                "PokeMini-libretro/source/MinxCPU.c",
                "PokeMini-libretro/source/MinxCPU_CE.c",
                "PokeMini-libretro/source/MinxCPU_CF.c",
                "PokeMini-libretro/source/MinxCPU_SP.c",
                "PokeMini-libretro/source/MinxCPU_XX.c",
                "PokeMini-libretro/source/MinxColorPRC.c",
                "PokeMini-libretro/source/MinxIO.c",
                "PokeMini-libretro/source/MinxIRQ.c",
                "PokeMini-libretro/source/MinxLCD.c",
                "PokeMini-libretro/source/MinxPRC.c",
                "PokeMini-libretro/source/MinxTimers.c",
                "PokeMini-libretro/source/Missing.c",
                "PokeMini-libretro/source/Multicart.c",
                "PokeMini-libretro/source/PMCommon.c",
                "PokeMini-libretro/source/PokeMini.c",
                "PokeMini-libretro/source/Video.c",
                "PokeMini-libretro/source/Video_x1.c",
                "PokeMini-libretro/source/Video_x2.c",
                "PokeMini-libretro/source/Video_x3.c",
                "PokeMini-libretro/source/Video_x4.c",
                "PokeMini-libretro/source/Video_x5.c",
                "PokeMini-libretro/source/Video_x6.c"
            ],
            packageAccess: true,
            cSettings: [
                .unsafeFlags([
                    "-fPIC",
                    "-fstrict-aliasing"
                ]),
                .define("NDEBUG", to: "1", .when(configuration: .release)),
                .define("LSB_FIRST"),
                .define("IOS"),
                .define("INLINE", to: INLINE),
                .define("__LIBRETRO__", to: __LIBRETRO__),
                .define("__GCCUNIX__", to: __GCCUNIX__),
                .define("NO_ZIP", to: NO_ZIP),
                .define("VIDEO_UPSCALE", to: VIDEO_UPSCALE),
                .headerSearchPath("include"),
                .headerSearchPath("PokeMini-libretro/source"),
                .headerSearchPath("PokeMini-libretro/freebios/"),
                .headerSearchPath("PokeMini-libretro/resource/"),
                .headerSearchPath("PokeMini-libretro/libretro/"),
                .headerSearchPath("PokeMini-libretro/libretro/libretro-common"),
                .headerSearchPath("PokeMini-libretro/libretro/libretro-common/include"),
            ]
        ),

        // MARK: Tests
        .testTarget(
            name: "PVPokeMiniTests",
            dependencies: [
                "PVPokeMini", "libpokemini", "PokeMiniC", "PVPokeMiniBridge"
            ]
        )
    ],
    swiftLanguageModes: [.v5, .v6],
    cLanguageStandard: .gnu99,
    cxxLanguageStandard: .gnucxx11
)
