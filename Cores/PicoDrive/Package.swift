// swift-tools-version:5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "PVPicoDrive",
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
            name: "PVPicoDrive",
            targets: ["PVPicoDrive", "PVPicoDriveSwift"]),
        .library(
            name: "PVPicoDrive-Dynamic",
            type: .dynamic,
            targets: ["PVPicoDrive", "PVPicoDriveSwift"]),
        .library(
            name: "PVPicoDrive-Static",
            type: .static,
            targets: ["PVPicoDrive", "PVPicoDriveSwift"]),
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
            name: "PVPicoDrive",
            dependencies: [
                "PVEmulatorCore",
                "PVCoreBridge",
                "PVSupport",
                "PVObjCUtils",
                "PVPicoDriveSwift",
                "libpicodrive"
//                "PVPicoDriveC"
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
                .headerSearchPath("../libpicodrive/"),
                .headerSearchPath("../libpicodrive/include/"),
                .headerSearchPath("../libpicodrive/platform/libretro/")
            ]
        ),

        .target(
            name: "PVPicoDriveSwift",
            dependencies: [
                "PVEmulatorCore",
                "PVCoreBridge",
                "PVLogging",
                "PVAudio",
                "PVSupport",
                "libpicodrive"
//                "PVPicoDriveC"
            ],
            cSettings: [
                .define("INLINE", to: "inline"),
                .define("USE_STRUCTS", to: "1"),
                .define("__LIBRETRO__", to: "1"),
                .define("HAVE_COCOATOJUCH", to: "1"),
                .define("__GCCUNIX__", to: "1"),
                .headerSearchPath("../libpicodrive/"),
                .headerSearchPath("../libpicodrive/include")
            ]
        ),

//        .target(
//            name: "PVPicoDriveC",
//            dependencies: [
//                "PVEmulatorCore",
//                "PVCoreBridge",
//                "PVLogging",
//                "PVAudio",
//                "PVSupport",
//                "libpicodrive",
//            ],
//            packageAccess: true,
//            cSettings: [
//                .define("INLINE", to: "inline"),
//                .define("USE_STRUCTS", to: "1"),
//                .define("__LIBRETRO__", to: "1"),
//                .define("HAVE_COCOATOJUCH", to: "1"),
//                .define("__GCCUNIX__", to: "1"),
//                .headerSearchPath("../libpicodrive/"),
//                .headerSearchPath("../libpicodrive/include")
//            ]
//        ),

        .target(
            name: "libpicodrive",
            exclude: [
            ],
            sources: [
                "cpu/cz80/cz80.c",
                "cpu/drc/cmn.c",
                "cpu/fame/famec.c",
                "cpu/sh2/mame/sh2pico.c",
                "cpu/sh2/sh2.c",
                "pico/32x/32x.c",
                "pico/32x/draw.c",
                "pico/32x/memory.c",
                "pico/32x/pwm.c",
                "pico/32x/sh2soc.c",
                "pico/cart.c",
                "pico/carthw/carthw.c",
                "pico/carthw/eeprom_spi.c",
                "pico/carthw/svp/memory.c",
                "pico/carthw/svp/ssp16.c",
                "pico/carthw/svp/svp.c",
                "pico/cd/cd_image.c",
                "pico/cd/cdc.c",
                "pico/cd/cdd.c",
                "pico/cd/cue.c",
                "pico/cd/gfx.c",
                "pico/cd/gfx_dma.c",
                "pico/cd/mcd.c",
                "pico/cd/memory.c",
                "pico/cd/misc.c",
                "pico/cd/pcm.c",
                "pico/cd/sek.c",
                "pico/debug.c",
                "pico/draw.c",
                "pico/draw2.c",
                "pico/eeprom.c",
                "pico/media.c",
                "pico/memory.c",
                "pico/misc.c",
                "pico/mode4.c",
                "pico/patch.c",
                "pico/pico.c",
                "pico/pico/memory.c",
                "pico/pico/pico.c",
                "pico/pico/xpcm.c",
                "pico/sek.c",
                "pico/sms.c",
                "pico/sound/mix.c",
                "pico/sound/sn76496.c",
                "pico/sound/sound.c",
                "pico/sound/ym2612.c",
                "pico/state.c",
                "pico/videoport.c",
                "pico/z80if.c",
                "platform/common/mp3.c",
                "platform/common/mp3_dummy.c",
                "platform/libretro/libretro.c",
                "unzip/unzip.c",
                "zlib/adler32.c",
                "zlib/compress.c",
                "zlib/crc32.c",
                "zlib/deflate.c",
                "zlib/gzio.c",
                "zlib/inffast.c",
                "zlib/inflate.c",
                "zlib/inftrees.c",
                "zlib/trees.c",
                "zlib/uncompr.c",
                "zlib/zutil.c",
            ],
            packageAccess: true,
            cSettings: [
                .define("NDEBUG", to: "1", .when(configuration: .release)),
                .define("DEBUG", to: "1", .when(configuration: .debug)),

                .define("EMU_F68K", to: "1"),
                .define("_USE_CZ80", to: "1"),

                .headerSearchPath("./"),
                .headerSearchPath("./include"),
                .headerSearchPath("./pico"),
            ]
        )
    ],
    swiftLanguageVersions: [.v5],
    cLanguageStandard: .gnu99,
    cxxLanguageStandard: .gnucxx14
)
