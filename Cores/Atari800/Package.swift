// swift-tools-version:5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "PVAtari800",
    platforms: [
        .iOS(.v13),
        .tvOS(.v13),
        .watchOS(.v9),
        .macOS(.v11),
        .macCatalyst(.v14)
    ],
    products: [
        // Products define the executables and libraries produced by a package, and make them visible to other packages.
        .library(
            name: "PVAtari800",
            targets: ["PVAtari800", "PVAtari800Swift"]),
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
            name: "PVAtari800",
            dependencies: [
                "PVEmulatorCore",
                "PVCoreBridge",
                "PVSupport",
                "PVObjCUtils",
                "PVAtari800Swift",
                "PVAtari800C",
                "libatari800",
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
                .headerSearchPath("../libatari800/src"),
                .headerSearchPath("../libatari800/src/m68000"),
                .headerSearchPath("../libatari800/libretro-common"),
                .headerSearchPath("../libatari800/libretro-common/include"),
            ]
        ),

        .target(
            name: "PVAtari800Swift",
            dependencies: [
                "PVEmulatorCore",
                "PVCoreBridge",
                "PVLogging",
                "PVAudio",
                "PVSupport",
                "libatari800",
                "PVAtari800C"
            ],
            cSettings: [
                .define("INLINE", to: "inline"),
                .define("USE_STRUCTS", to: "1"),
                .define("__LIBRETRO__", to: "1"),
                .define("HAVE_COCOATOJUCH", to: "1"),
                .define("__GCCUNIX__", to: "1"),
                .headerSearchPath("../libatari800/src"),
                .headerSearchPath("../libatari800/src/m68000"),
                .headerSearchPath("../libatari800/libretro-common"),
                .headerSearchPath("../libatari800/libretro-common/include"),
            ]
        ),

        .target(
            name: "PVAtari800C",
            dependencies: [
                "PVEmulatorCore",
                "PVCoreBridge",
                "PVLogging",
                "PVAudio",
                "PVSupport",
                "libatari800",
            ],
            cSettings: [
                .define("INLINE", to: "inline"),
                .define("USE_STRUCTS", to: "1"),
                .define("__LIBRETRO__", to: "1"),
                .define("HAVE_COCOATOJUCH", to: "1"),
                .define("__GCCUNIX__", to: "1"),
                .headerSearchPath("../libatari800/include"),
                .headerSearchPath("../libatari800/atari800-src"),
            ]
        ),

        .target(
            name: "libatari800",
            exclude: [
            ],
            sources: [
                "atari800-src/afile.c",
                "atari800-src/antic.c",
                "atari800-src/artifact.c",
                "atari800-src/atari.c",
                "atari800-src/binload.c",
                "atari800-src/cartridge.c",
                "atari800-src/cassette.c",
                "atari800-src/cfg.c",
                "atari800-src/colours.c",
                "atari800-src/colours_external.c",
                "atari800-src/colours_ntsc.c",
                "atari800-src/colours_pal.c",
                "atari800-src/compfile.c",
                "atari800-src/cpu.c",
                "atari800-src/crc32.c",
                "atari800-src/cycle_map.c",
                "atari800-src/devices.c",
                "atari800-src/emuos.c",
                "atari800-src/esc.c",
                "atari800-src/gtia.c",
                "atari800-src/ide.c",
                "atari800-src/img_tape.c",
                "atari800-src/input.c",
                "atari800-src/log.c",
                "atari800-src/memory.c",
                "atari800-src/monitor.c",
                "atari800-src/mzpokeysnd.c",
                "atari800-src/pbi.c",
                "atari800-src/pbi_bb.c",
                "atari800-src/pbi_mio.c",
                "atari800-src/pbi_scsi.c",
                "atari800-src/pia.c",
                "atari800-src/pokey.c",
                "atari800-src/pokeysnd.c",
                "atari800-src/remez.c",
                "atari800-src/rtime.c",
                "atari800-src/screen.c",
                "atari800-src/sio.c",
                "atari800-src/sndsave.c",
                "atari800-src/sound.c",
                "atari800-src/statesav.c",
                "atari800-src/sysrom.c",
                "atari800-src/ui_basic.c",
                "atari800-src/util.c"
            ],
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
