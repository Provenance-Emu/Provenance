// swift-tools-version:6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "PVCorePicoDrive",
    platforms: [
        .iOS(.v17),
        .tvOS(.v17),
        .watchOS(.v9),
        .macOS(.v11),
        .macCatalyst(.v17),
        .visionOS(.v1)
    ],
    products: [
        // Products define the executables and libraries produced by a package, and make them visible to other packages.
        .library(
            name: "PVPicoDrive",
            targets: ["PVPicoDrive"]),
        .library(
            name: "PVPicoDrive-Dynamic",
            type: .dynamic,
            targets: ["PVPicoDrive"]),
        .library(
            name: "PVPicoDrive-Static",
            type: .static,
            targets: ["PVPicoDrive"])
    ],
    dependencies: [
        .package(path: "../../PVAudio"),
        .package(path: "../../PVCoreBridge"),
        .package(path: "../../PVCoreObjCBridge"),
        .package(path: "../../PVEmulatorCore"),
        .package(path: "../../PVLogging"),
        .package(path: "../../PVObjCUtils"),
        .package(path: "../../PVPlists"),
        .package(path: "../../PVSettings"),
        .package(path: "../../PVSupport"),
        .package(name: "PVPrimitives", path: "../../PVPrimitives/"),
        .package(name: "PVNetplay", path: "../../PVNetplay"),
        .package(path: "../../PVRcheevos"),
        .package(name: "PVRcheevosBridge", path: "../../PVRcheevosBridge"),

        .package(url: "https://github.com/Provenance-Emu/SwiftGenPlugin.git", from: "1.1.3"),
    ],
    targets: [
        
        // MARK: --------- Core ---------- //
        
        
        .target(
            name: "PVPicoDrive",
            dependencies: [
                "PVEmulatorCore",
                "PVCoreBridge",
                "PVCoreObjCBridge",
                "PVLogging",
                "PVAudio",
                "PVSupport",
                "PVPrimitives",
                "libpicodrive",
                "PVPicoDriveBridge",
                "PVSettings",
                .product(name: "PVRcheevos", package: "PVRcheevos"),
                .product(name: "PVRcheevosBridge", package: "PVRcheevosBridge"),
            ],
            resources: [
                .process("Resources/Core.plist"),
                .copy("Resources/carthw.cfg")
            ],
            cSettings: [
                .define("INLINE", to: "inline"),
                .define("USE_STRUCTS", to: "1"),
                .define("__LIBRETRO__", to: "1"),
                .define("HAVE_COCOATOJUCH", to: "1"),
                .define("__GCCUNIX__", to: "1"),
                .headerSearchPath("../libpicodrive/picodrive"),
                .headerSearchPath("../libpicodrive/include")
            ],
            plugins: [
                // Disabled until SwiftGenPlugin support Swift 6 concurrency
                .plugin(name: "SwiftGenPlugin", package: "SwiftGenPlugin")
            ]
        ),

        // MARK: --------- Bridge ---------- //

        .target(
            name: "PVPicoDriveBridge",
            dependencies: [
                "PVEmulatorCore",
                "PVCoreBridge",
                "PVCoreObjCBridge",
                "PVSupport",
                "PVPlists",
                "PVObjCUtils",
                "libpicodrive",
                "PVSettings"
            ],
            publicHeadersPath: "include",
            cSettings: [
                .define("INLINE", to: "inline"),
                .define("USE_STRUCTS", to: "1"),
                .define("__LIBRETRO__", to: "1"),
                .define("HAVE_COCOATOJUCH", to: "1"),
                .define("__GCCUNIX__", to: "1"),
                .headerSearchPath("../libpicodrive/picodrive"),
                .headerSearchPath("../libpicodrive/include/"),
                .headerSearchPath("../libpicodrive/picodrive/platform/libretro/"),
                .headerSearchPath("../libpicodrive/picodrive/platform/libretro/libretro-common/include/")
            ]
        ),


        // MARK: --------- Emulator ---------- //

            .target(
                name: "libpicodrive",
                dependencies: ["unzip"],
                exclude: [
                ],
                sources: [
                    "picodrive/cpu/cz80/cz80.c",
                    "picodrive/cpu/drc/cmn.c",
                    "picodrive/cpu/fame/famec.c",
                    "picodrive/cpu/sh2/mame/sh2pico.c",
                    "picodrive/cpu/sh2/sh2.c",
                    "picodrive/pico/32x/32x.c",
                    "picodrive/pico/32x/draw.c",
                    "picodrive/pico/32x/memory.c",
                    "picodrive/pico/32x/pwm.c",
                    "picodrive/pico/32x/sh2soc.c",
                    "picodrive/pico/cart.c",
                    "picodrive/pico/carthw/carthw.c",
                    "picodrive/pico/carthw/eeprom_spi.c",
                    "picodrive/pico/carthw/svp/memory.c",
                    "picodrive/pico/carthw/svp/ssp16.c",
                    "picodrive/pico/carthw/svp/svp.c",
                    "picodrive/pico/cd/cd_image.c",
                    "picodrive/pico/cd/cd_parse.c",
                    "picodrive/pico/cd/cdc.c",
                    "picodrive/pico/cd/cdd.c",
                    "picodrive/pico/cd/gfx.c",
                    "picodrive/pico/cd/gfx_dma.c",
                    "picodrive/pico/cd/mcd.c",
                    "picodrive/pico/cd/megasd.c",
                    "picodrive/pico/cd/memory.c",
                    "picodrive/pico/cd/misc.c",
                    "picodrive/pico/cd/pcm.c",
                    "picodrive/pico/cd/sek.c",
                    "picodrive/pico/debug.c",
                    "picodrive/pico/draw.c",
                    "picodrive/pico/draw2.c",
                    "picodrive/pico/eeprom.c",
                    "picodrive/pico/media.c",
                    "picodrive/pico/memory.c",
                    "picodrive/pico/misc.c",
                    "picodrive/pico/mode4.c",
                    "picodrive/pico/patch.c",
                    "picodrive/pico/pico.c",
                    "picodrive/pico/pico/memory.c",
                    "picodrive/pico/pico/pico.c",
                    "picodrive/pico/pico/xpcm.c",
                    "picodrive/pico/sek.c",
                    "picodrive/pico/sms.c",
                    "picodrive/pico/sound/mix.c",
                    "picodrive/pico/sound/resampler.c",
                    "picodrive/pico/sound/sn76496.c",
                    "picodrive/pico/sound/sound.c",
                    "picodrive/pico/sound/ym2612.c",
                    "picodrive/pico/sound/ym2413.c",
                    "picodrive/pico/state.c",
                    "picodrive/pico/videoport.c",
                    "picodrive/pico/z80if.c",
                    "picodrive/platform/common/mp3.c",
                    "picodrive/platform/common/mp3_sync.c",
                    "picodrive/platform/common/mp3_dummy.c",
                    "picodrive/platform/libretro/libretro.c",
                    "picodrive/platform/libretro/libretro-common/compat/compat_posix_string.c",
                    "picodrive/platform/libretro/libretro-common/compat/compat_strcasestr.c",
                    "picodrive/platform/libretro/libretro-common/compat/compat_strl.c",
                    "picodrive/platform/libretro/libretro-common/compat/fopen_utf8.c",
                    "picodrive/platform/libretro/libretro-common/encodings/encoding_utf.c",
                    "picodrive/platform/libretro/libretro-common/file/file_path.c",
                    "picodrive/platform/libretro/libretro-common/file/file_path_io.c",
                    "picodrive/platform/libretro/libretro-common/formats/png/rpng.c",
                    "picodrive/platform/libretro/libretro-common/memmap/memmap.c",
                    "picodrive/platform/libretro/libretro-common/streams/file_stream.c",
                    "picodrive/platform/libretro/libretro-common/streams/file_stream_transforms.c",
                    "picodrive/platform/libretro/libretro-common/streams/trans_stream.c",
                    "picodrive/platform/libretro/libretro-common/streams/trans_stream_pipe.c",
                    "picodrive/platform/libretro/libretro-common/string/stdstring.c",
                    "picodrive/platform/libretro/libretro-common/time/rtime.c",
                    "picodrive/platform/libretro/libretro-common/vfs/vfs_implementation.c"
                ],
                resources: [
                    .copy("picodrive/pico/carthw.cfg")
                ],
                packageAccess: true,
                cSettings: [
                    .define("NDEBUG", to: "1", .when(configuration: .release)),
                    .define("DEBUG", to: "1", .when(configuration: .debug)),

                    .define("EMU_F68K", to: "1"),
                    .define("_USE_CZ80", to: "1"),
                    .define("REVISION", to: "\"\""),

                    .headerSearchPath("./picodrive"),
                    .headerSearchPath("./include"),
                    .headerSearchPath("./picodrive/pico"),
                    .headerSearchPath("./picodrive/platform/libretro"),
                    .headerSearchPath("./picodrive/platform/libretro/libretro-common/include")
                ]
            ),

//            .target(
//                name: "zlib",
//                sources: [
//                    "adler32.c",
//                    "compress.c",
//                    "crc32.c",
//                    "deflate.c",
//                    "gzio.c",
//                    "inffast.c",
//                    "inflate.c",
//                    "inftrees.c",
//                    "trees.c",
//                    "uncompr.c",
//                    "zutil.c"
//                ],
//                publicHeadersPath: "./",
//                packageAccess: true,
//                cSettings: [
//                    .define("NDEBUG", to: "1", .when(configuration: .release)),
//                    .define("DEBUG", to: "1", .when(configuration: .debug)),
//
//                    .define("EMU_F68K", to: "1"),
//                    .define("_USE_CZ80", to: "1"),
//
//                    .headerSearchPath("./"),
//                    .headerSearchPath("./include"),
//                    .headerSearchPath("./pico"),
//                ],
//                linkerSettings: [
//                    .linkedLibrary("z")
//                ]
//            ),

        // MARK: --------- libunzip ---------- //

            .target(
                name: "unzip",
//                dependencies: [ "zlib" ],
                sources: [
                    "unzip.c"
                ],
                publicHeadersPath: "./",
                packageAccess: true,
                cSettings: [
                    .define("NDEBUG", to: "1", .when(configuration: .release)),
                    .define("DEBUG", to: "1", .when(configuration: .debug)),

                    .define("EMU_F68K", to: "1"),
                    .define("_USE_CZ80", to: "1"),

                    .headerSearchPath("./"),
                    .headerSearchPath("./include"),
                    .headerSearchPath("./pico"),
                ],
                linkerSettings: [
                    .linkedLibrary("z"),
                ]
            ),

        // MARK: --------- Tests ---------- //
        .testTarget(name: "PVPicoDriveTests",
                    dependencies: ["PVPicoDrive"])
    ],
    swiftLanguageModes: [.v5, .v6],
    cLanguageStandard: .gnu99,
    cxxLanguageStandard: .gnucxx14
)
