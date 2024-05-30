// swift-tools-version:5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "PVPokeMini",
    platforms: [
        .iOS(.v13),
        .tvOS(.v13),
        .watchOS(.v9),
        .macOS(.v11),
        .macCatalyst(.v14),
        .visionOS(.v1)
    ],
    products: [
        // Products define the executables and libraries produced by a package, and make them visible to other packages.
        .library(
            name: "PVPokeMini",
            targets: ["PVPokeMini", "PokeMiniSwift", "libpokemini"]),
        .library(
            name: "PVPokeMini-Dynamic",
            type: .dynamic,
            targets: ["PVPokeMini", "PokeMiniSwift", "libpokemini"]),
        .library(
            name: "PVPokeMini-Static",
            type: .static,
            targets: ["PVPokeMini", "PokeMiniSwift", "libpokemini"])
    ],
    dependencies: [
        .package(path: "../../PVCoreBridge"),
        .package(path: "../../PVEmulatorCore"),
        .package(path: "../../PVAudio"),
        .package(path: "../../PVLogging"),
        .package(path: "../../PVObjCUtils")
    ],
    targets: [
        .target(
            name: "PVPokeMini",
            dependencies: [
                "PVEmulatorCore",
                "PVCoreBridge",
                "PVObjCUtils",
                "PVLogging",
                "PokeMiniSwift",
                "PokeMiniC",
                "libpokemini"
            ],
            resources: [
                .copy("Resources/Core.plist")
            ],
            publicHeadersPath: "include",
            cSettings: [
                .define("INLINE", to: "inline"),
                .define("USE_STRUCTS", to: "1"),
                .define("__LIBRETRO__", to: "1"),
                .define("HAVE_COCOATOJUCH", to: "1"),
                .define("__GCCUNIX__", to: "1"),
                .define("NO_ZIP", to: "1"),
                .headerSearchPath("../libpokemini/include"),
                .headerSearchPath("../libpokemini/PokeMini-libretro/src"),
                .headerSearchPath("../libpokemini/PokeMini-libretro/src/m68000"),
                .headerSearchPath("../libpokemini/PokeMini-libretro/libretro-common"),
                .headerSearchPath("../libpokemini/PokeMini-libretro/libretro-common/include"),
            ]
        ),

        .target(
            name: "PokeMiniSwift",
            dependencies: [
                "PVEmulatorCore",
                "PVCoreBridge",
                "PVLogging",
                "PVAudio",
                "libpokemini",
                "PokeMiniC"
            ],
            cSettings: [
                .define("INLINE", to: "inline"),
                .define("USE_STRUCTS", to: "1"),
                .define("__LIBRETRO__", to: "1"),
                .define("HAVE_COCOATOJUCH", to: "1"),
                .define("__GCCUNIX__", to: "1"),
                .define("NO_ZIP", to: "1"),
                .headerSearchPath("../libpokemini/include"),
                .headerSearchPath("../libpokemini/PokeMini-libretro/src"),
                .headerSearchPath("../libpokemini/PokeMini-libretro/src/m68000"),
                .headerSearchPath("../libpokemini/PokeMini-libretro/libretro-common"),
                .headerSearchPath("../libpokemini/PokeMini-libretro/libretro-common/include"),
            ]
        ),

        .target(
            name: "PokeMiniC",
            dependencies: [
                "PVEmulatorCore",
                "PVCoreBridge",
                "PVLogging",
                "PVAudio",
                "libpokemini",
            ],
            cSettings: [
                .define("INLINE", to: "inline"),
                .define("USE_STRUCTS", to: "1"),
                .define("__LIBRETRO__", to: "1"),
                .define("HAVE_COCOATOJUCH", to: "1"),
                .define("__GCCUNIX__", to: "1"),
                .define("NO_ZIP", to: "1"),
                .headerSearchPath("../libpokemini/include/"),
                .headerSearchPath("../libpokemini/PokeMini-libretro/source"),
                .headerSearchPath("../libpokemini/PokeMini-libretro/freebios/"),
                .headerSearchPath("../libpokemini/PokeMini-libretro/resource/"),
                .headerSearchPath("../libpokemini/PokeMini-libretro/libretro/"),
                .headerSearchPath("../libpokemini/PokeMini-libretro/libretro/libretro-common"),
                .headerSearchPath("../libpokemini/PokeMini-libretro/libretro/libretro-common/include"),
            ]
        ),

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
                "PokeMini-libretro/source/MinxColorPRC.c",
                "PokeMini-libretro/source/MinxCPU.c",
                "PokeMini-libretro/source/MinxCPU_CE.c",
                "PokeMini-libretro/source/MinxCPU_CF.c",
                "PokeMini-libretro/source/MinxCPU_SP.c",
                "PokeMini-libretro/source/MinxCPU_XX.c",
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
                .define("INLINE", to: "inline"),
                .define("USE_STRUCTS", to: "1"),
                .define("__LIBRETRO__", to: "1"),
                .define("HAVE_COCOATOUCH", to: "1"),
                .define("__GCCUNIX__", to: "1"),
                .define("NO_ZIP", to: "1"),
                .headerSearchPath("include"),
                .headerSearchPath("PokeMini-libretro/source"),
                .headerSearchPath("PokeMini-libretro/freebios/"),
                .headerSearchPath("PokeMini-libretro/resource/"),
                .headerSearchPath("PokeMini-libretro/libretro/"),
                .headerSearchPath("PokeMini-libretro/libretro/libretro-common"),
                .headerSearchPath("PokeMini-libretro/libretro/libretro-common/include"),
            ]
        )
    ],
    swiftLanguageVersions: [.v5],
    cLanguageStandard: .gnu17,
    cxxLanguageStandard: .gnucxx14
)
