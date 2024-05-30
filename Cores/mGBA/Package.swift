// swift-tools-version:5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "PVmGBA",
    platforms: [
        .iOS(.v13),
        .tvOS(.v13),
        .watchOS(.v9),
        .macOS(.v10_13),
        .macCatalyst(.v14),
        .visionOS(.v1)
    ],
    products: [
        // Products define the executables and libraries produced by a package, and make them visible to other packages.
        .library(
            name: "PVmGBA",
            targets: ["PVmGBA", "PVmGBASwift"]),
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
            name: "PVmGBA",
            dependencies: [
                "PVEmulatorCore",
                "PVCoreBridge",
                "PVSupport",
                "PVObjCUtils",
                "PVmGBASwift",
                "PVmGBAC",
                "libmGBA"
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
                .headerSearchPath("../libretro-mGBA/src"),
                .headerSearchPath("../libretro-mGBA/src/m68000"),
                .headerSearchPath("../libretro-mGBA/libretro-common"),
                .headerSearchPath("../libretro-mGBA/libretro-common/include"),
            ]
        ),

        .target(
            name: "PVmGBASwift",
            dependencies: [
                "PVEmulatorCore",
                "PVCoreBridge",
                "PVLogging",
                "PVAudio",
                "PVSupport",
                "libmGBA",
            ],
            cSettings: [
                .define("INLINE", to: "inline"),
                .define("USE_STRUCTS", to: "1"),
                .define("__LIBRETRO__", to: "1"),
                .define("HAVE_COCOATOJUCH", to: "1"),
                .define("__GCCUNIX__", to: "1"),
                .headerSearchPath("../libretro-mGBA/src"),
                .headerSearchPath("../libretro-mGBA/src/m68000"),
                .headerSearchPath("../libretro-mGBA/libretro-common"),
                .headerSearchPath("../libretro-mGBA/libretro-common/include"),
            ]
        ),

        .target(
            name: "PVmGBAC",
            dependencies: [
                "PVEmulatorCore",
                "PVCoreBridge",
                "PVLogging",
                "PVAudio",
                "PVSupport",
                "libmGBA",
            ],
            cSettings: [
                .define("INLINE", to: "inline"),
                .define("USE_STRUCTS", to: "1"),
                .define("__LIBRETRO__", to: "1"),
                .define("HAVE_COCOATOJUCH", to: "1"),
                .define("__GCCUNIX__", to: "1"),
                .headerSearchPath("../libretro-mGBA/src"),
                .headerSearchPath("../libretro-mGBA/src/m68000"),
                .headerSearchPath("../libretro-mGBA/libretro-common"),
                .headerSearchPath("../libretro-mGBA/libretro-common/include"),
            ]
        ),

        .target(
            name: "libmGBA",
            exclude: [
                "en.lproj",
                "src/platform/openemu/"
            ],
            sources: [
                "src/arm/arm.c",
                "src/arm/decoder-arm.c",
                "src/arm/decoder-thumb.c",
                "src/arm/decoder.c",
                "src/arm/isa-arm.c",
                "src/arm/isa-thumb.c",
                "src/core/bitmap-cache.c",
                "src/core/cache-set.c",
                "src/core/cheats.c",
                "src/core/config.c",
                "src/core/core.c",
                "src/core/directories.c",
                "src/core/input.c",
                "src/core/interface.c",
                "src/core/library.c",
                "src/core/lockstep.c",
                "src/core/log.c",
                "src/core/map-cache.c",
                "src/core/mem-search.c",
                "src/core/rewind.c",
                "src/core/serialize.c",
                "src/core/sync.c",
                "src/core/thread.c",
                "src/core/tile-cache.c",
                "src/core/timing.c",
                "src/gb/audio.c",
                "src/gba/audio.c",
                "src/gba/bios.c",
                "src/gba/cheats.c",
                "src/gba/cheats/codebreaker.c",
                "src/gba/cheats/gameshark.c",
                "src/gba/cheats/parv3.c",
                "src/gba/core.c",
                "src/gba/dma.c",
                "src/gba/ereader.c",
                "src/gba/gba.c",
                "src/gba/hardware.c",
                "src/gba/hle-bios.c",
                "src/gba/input.c",
                "src/gba/io.c",
                "src/gba/matrix.c",
                "src/gba/memory.c",
                "src/gba/overrides.c",
                "src/gba/renderers/cache-set.c",
                "src/gba/renderers/common.c",
                "src/gba/renderers/software-bg.c",
                "src/gba/renderers/software-mode0.c",
                "src/gba/renderers/software-obj.c",
                "src/gba/renderers/video-software.c",
                "src/gba/savedata.c",
                "src/gba/serialize.c",
                "src/gba/sio.c",
                "src/gba/sio/lockstep.c",
                "src/gba/timer.c",
                "src/gba/vfame.c",
                "src/gba/video.c",
                "src/platform/posix/memory.c",
                "src/third-party/blip_buf/blip_buf.c",
                "src/third-party/inih/ini.c",
                "src/util/circle-buffer.c",
                "src/util/configuration.c",
                "src/util/crc32.c",
                "src/util/export.c",
                "src/util/formatting.c",
                "src/util/gbk-table.c",
                "src/util/hash.c",
                "src/util/patch-ips.c",
                "src/util/patch-ups.c",
                "src/util/patch.c",
                "src/util/string.c",
                "src/util/table.c",
                "src/util/text-codec.c",
                "src/util/vfs.c",
                "src/util/vfs/vfs-dirent.c",
                "src/util/vfs/vfs-fd.c",
                "src/util/vfs/vfs-fifo.c",
                "src/util/vfs/vfs-mem.c",
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
